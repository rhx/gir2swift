//
//  girtype.swift
//  libgir2swift
//
//  Created by Rene Hexel on 18/7/20.
//  Copyright © 2020 Rene Hexel. All rights reserved.
//
import Foundation

/// Representation of a fundamental type, its relationship to other types,
/// and casting operations
public class GIRType: Hashable {
    /// Name of the type defined in the GIR file
    public let name: String
    /// Name of the type in Swift
    public var swiftName: String
    /// Name of the type
    public let typeName: String
    /// Name of the type in C
    public let ctype: String
    /// The supertype (or equivalent, if alias) of this type
    public var parent: TypeReference?
    /// Indicator whether this type is an alias that doesn't need casting
    public let isAlias: Bool
    /// Dictionary of possible type conversion (cast) operations to target types.
    /// - Note: The index into the array is the level of constness and indirection*2,
    /// e.g., `0` is direct, non-const, `1` is direct and `const`, `2` is a single-level,
    /// mutable pointer, `3`, is a single-level immutable pointer, `4` is a mutable pointer
    /// to a pointer, `5` is an immutable pointer to a pointer, etc.
    public var conversions: [GIRType : [TypeConversion]] = [:]

    /// Swift name to use for casting: replaces trailing `!` with `?`
    @inlinable public var castName: String {
        guard swiftName.hasSuffix("!") else {
            return swiftName.hasSuffix("Ref") || GIR.knownBitfields[swiftName] != nil ? swiftName : typeName
        }
        let s = swiftName.startIndex
        let e = swiftName.index(before: swiftName.endIndex)
        return swiftName[s..<e] + "?"
    }

    /// Return an equivalent type from the current namespace
    @inlinable public var prefixed: GIRType {
        guard !GIR.dottedPrefix.isEmpty && name.firstIndex(of: ".") == nil else { return self }
        let prefixed = GIR.dottedPrefix.withNormalisedPrefix + name
        let swPrefixed = swiftName.firstIndex(of: ".") == nil ? (GIR.dottedPrefix.withNormalisedPrefix + swiftName) : swiftName
        return GIRType(name: prefixed, swiftName: swPrefixed, typeName: typeName, ctype: ctype, superType: parent, isAlias: isAlias, conversions: conversions)
    }

    /// Designated initialiser for a GIR type
    /// - Parameters:
    ///   - name: The name of the type
    ///   - swiftName: The name of the type in Swift (empty or `nil` if same as `name`)
    ///   - typeName: The name of the underlying type (empty or `nil` if same as `swiftName`)
    ///   - ctype: The name of the type in C
    ///   - superType: The parent or alias type (or `nil` if fundamental)
    ///   - isAlias: An indicator whether the type is an alias of its supertype that does not need casting
    @inlinable
    public init(name: String, swiftName: String? = nil, typeName: String? = nil, ctype: String, superType: TypeReference? = nil, isAlias: Bool = false, conversions: [GIRType : [TypeConversion]] = [:]) {
        precondition(isAlias == false || superType != nil)
        self.name = name
        let swiftDefault = swiftName.map { $0.isEmpty ? name : $0 } ?? name
        let swift = GIR.underlyingPrimitiveSwiftTypes[swiftDefault] ?? swiftDefault
        self.swiftName = swift
        self.typeName = typeName.map { $0.isEmpty ? swift : $0 } ?? swift
        self.ctype = ctype
        self.parent = superType
        self.isAlias = isAlias
        self.conversions = conversions
    }

    /// Initialise a new type as an alias of the given type reference,
    /// cloning its type conversions
    /// - Parameters:
    ///   - typeReference: A reference to the type to alias
    ///   - name: The name of the new alias, or `nil` if the same as the aliased type
    ///   - swiftName: The swift name of the new alias, or `nil` if the same as the aliased type
    ///   - ctype: The C type of the new alias, or `nil` if the same as the aliased type
    @inlinable
    public convenience init(aliasOf typeReference: TypeReference, name: String? = nil, swiftName: String? = nil, ctype: String? = nil) {
        let t = typeReference.type
        self.init(name: name ?? t.name, swiftName: swiftName ?? t.swiftName, ctype: ctype ?? t.ctype, superType: typeReference, isAlias: true, conversions: typeReference.indirectionLevel == 0 ? typeReference.type.conversions : [:])
    }

    /// Initialise a new type as an alias of the given type reference,
    /// cloning its type conversions
    /// - Parameters:
    ///   - aliasOf: The type to alias
    ///   - name: The name of the new alias, or `nil` if the same as the aliased type
    ///   - swiftName: The swift name of the new alias, or `nil` if the same as the aliased type
    ///   - ctype: The C type of the new alias, or `nil` if the same as the aliased type
    /// - Note: One of the name or type parameters should be non-`nil` for this alias to define a new type
    @inlinable
    public convenience init(aliasOf: GIRType, name: String? = nil, swiftName: String? = nil, ctype: String? = nil) {
        self.init(aliasOf: TypeReference(type: aliasOf), name: name, swiftName: swiftName, ctype: ctype)
    }

    /// Return an explicitly known cast to convert the given expression to the target type
    /// - Parameters:
    ///   - expression: The expression to cast
    ///   - target: The target type to cast to
    ///   - pointerLevel: The number of indirection levels (pointers)
    ///   - const: An indicator whether the cast is to a `const` value
    /// - Returns: The cast expression string, or `nil` if there is no way to cast to `target`
    @inlinable
    public func knownCast(expression: String, to target: GIRType, pointerLevel: Int = 0, const: Bool = false) -> String? {
        guard let conversion = conversions[target] else {
            if pointerLevel == 0 {
                guard !GIR.enums.contains(self) else {
                    let c = EnumTypeConversion(source: self, target: target)
                    conversions[target] = [c, c]
                    return c.castToTarget(from: expression)
                }
                guard !GIR.bitfields.contains(self) else {
                    let c = BitfieldTypeConversion(source: self, target: target)
                    conversions[target] = [c, c]
                    return c.castToTarget(from: expression)
                }
            }
           return nil
        }
        let i = 2*pointerLevel + (const ? 1 : 0)
        guard i < conversion.count else { return nil }
        return conversion[i].castToTarget(from: expression)
    }

    /// Return  an explicitly known cast to convert the given expression to the target type
    /// - Parameters:
    ///   - expression: The expression to cast
    ///   - source: The source type to cast from
    ///   - pointerLevel: The number of indirection levels (pointers)
    ///   - const: An indicator whether the cast is to a `const` value
    /// - Returns: The cast expression string, or `nil` if there is no way to cast from `source`
    @inlinable
    public func knownCast(expression e: String, from source: GIRType, pointerLevel: Int = 0, const: Bool = false) -> String? {
        guard let conversion = conversions[source] else {
            if pointerLevel == 0 {
                guard !GIR.enums.contains(self) else {
                    let c = EnumTypeConversion(source: source, target: self)
                    conversions[source] = [c, c]
                    return c.castFromTarget(expression: e)
                }
                guard !GIR.bitfields.contains(self) else {
                    let c = BitfieldTypeConversion(source: source, target: self)
                    conversions[source] = [c, c]
                    return c.castFromTarget(expression: e)
                }
                let sourceC = source.ctype
                if sourceC == GIR.gpointer || sourceC == GIR.gconstpointer {
                    if GIR.refRecords[self] != nil {
                        return name + "(" + sourceC + ": " + e + ")"
                    }
                }
            }
            return nil
        }
        let i = 2*pointerLevel + (const ? 1 : 0)
        guard i < conversion.count else { return nil }
        return conversion[i].castFromTarget(expression: e)
    }

    /// Return the default cast to convert the given expression to the target type
    /// - Parameters:
    ///   - expression: The expression to cast
    ///   - target: The target type to cast to
    ///   - pointerLevel: The number of indirection levels (pointers)
    ///   - const: An indicator whether the cast is to a `const` value
    /// - Returns: The cast expression string
    @inlinable
    public func cast(expression: String, to target: GIRType, pointerLevel: Int = 0, const: Bool = false) -> String {
        if let castExpr = knownCast(expression: expression, to: target, pointerLevel: pointerLevel, const: const) {
            return castExpr
        }
        let prefix: String
        if pointerLevel == 0 {
            prefix = target.castName
        } else {
            let ptr = const ? "UnsafePointer" : "UnsafeMutablePointer"
            prefix = ptr + "<" + target.castName + ">"
        }
        return prefix + "(" + expression + ")"
    }

    /// Return the default cast to convert the given expression from the source type
    /// - Parameters:
    ///   - expression: The expression to cast
    ///   - source: The source type to cast from
    ///   - pointerLevel: The number of indirection levels (pointers)
    ///   - const: An indicator whether the cast is to a `const` value
    /// - Returns: The cast expression string
    @inlinable
    public func cast(expression e: String, from source: GIRType, pointerLevel indirection: Int = 0, const isConst: Bool = false) -> String {
        if let castExpr = knownCast(expression: e, from: source, pointerLevel: indirection, const: isConst) {
            return castExpr
        }
        let castExpr = cast(expression: e, pointerLevel: indirection, const: isConst)
        return castExpr
    }

    /// Return the default cast to convert the given expression to the receiver
    /// - Parameters:
    ///   - expression: The expression to cast
    ///   - source: The source type to cast from
    ///   - pointerLevel: The number of indirection levels (pointers)
    ///   - const: An indicator whether the cast is to a `const` value
    /// - Returns: The cast expression string
    @inlinable
    public func cast(expression e: String, pointerLevel: Int = 0, const: Bool = false) -> String {
        let prefix: String
        if pointerLevel == 0 {
            prefix = castName
        } else if GIR.rawPointerTypes.contains(self) {
            return RawPointerConversion(source: self, target: self).castFromTarget(expression: e)
        } else {
            let ptr = const ? "UnsafePointer" : "UnsafeMutablePointer"
            prefix = ptr + "<" + castName + ">"
        }
        return prefix + "(" + e + ")"
    }

    /// Equality check for a type.
    /// Two types are considered equal if they have the same names and C types.
    /// - Parameters:
    ///   - lhs: The left hand side type to compare
    ///   - rhs: The right hand side type to compare
    /// - Returns: `true` if both types are considered equal
    @inlinable
    public static func == (lhs: GIRType, rhs: GIRType) -> Bool {
        return /* lhs.isAlias == rhs.isAlias && lhs.parent == rhs.parent && */
            lhs.ctype == rhs.ctype
            && lhs.name == rhs.name && lhs.swiftName == rhs.swiftName && lhs.typeName == rhs.typeName
    }

    /// Hashes the essential components of this type by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(swiftName)
        hasher.combine(typeName)
        hasher.combine(ctype)
//        hasher.combine(isAlias)
    }
}

/// Representation of a string type, its relationship to other types,
/// and casting operations
public final class GIRStringType: GIRType {
    /// Return the default cast to convert the given expression to a string
    /// - Parameters:
    ///   - expression: The expression to cast
    ///   - source: The source type to cast from
    ///   - pointerLevel: The number of indirection levels (pointers)
    ///   - const: An indicator whether the cast is to a `const` value
    /// - Returns: The cast expression string
    @inlinable
    override public func cast(expression e: String, pointerLevel: Int = 0, const: Bool = false) -> String {
        let cast = e + ".map({ " + castName + "(cString: $0) })"
        return cast
    }
}

/// Representation of a raw pointer type, its relationship to other types,
/// and casting operations
public final class GIRRawPointerType: GIRType {
    /// Return the default cast to convert the given expression to an opaque pointer
    /// - Parameters:
    ///   - expression: The expression to cast
    ///   - source: The source type to cast from
    ///   - pointerLevel: The number of indirection levels (pointers)
    ///   - const: An indicator whether the cast is to a `const` value
    /// - Returns: The cast expression string
    @inlinable
    public override func cast(expression e: String, pointerLevel: Int = 0, const: Bool = false) -> String {
        let expression = castName + "(" + e + ")"
        return expression
    }
}

/// Representation of a record type (struct or class), its relationship to other types,
/// and casting operations
public final class GIRRecordType: GIRType {
    /// Return the default cast to convert the given expression to an opaque pointer
    /// - Parameters:
    ///   - expression: The expression to cast
    ///   - source: The source type to cast from
    ///   - pointerLevel: The number of indirection levels (pointers)
    ///   - const: An indicator whether the cast is to a `const` value
    /// - Returns: The cast expression string
    @inlinable
    public override func cast(expression e: String, pointerLevel: Int = 0, const: Bool = false) -> String {
        let expression = castName + "(" + GIR.gconstpointer + ": " + GIR.gconstpointer + "(" + e + "))"
        return expression
    }
}

/// Representation of a opaque pointer type, its relationship to other types,
/// and casting operations
public final class GIROpaquePointerType: GIRType {
    /// Return the default cast to convert the given expression to an opaque pointer
    /// - Parameters:
    ///   - expression: The expression to cast
    ///   - source: The source type to cast from
    ///   - pointerLevel: The number of indirection levels (pointers)
    ///   - const: An indicator whether the cast is to a `const` value
    /// - Returns: The cast expression string
    @inlinable
    public override func cast(expression e: String, pointerLevel: Int = 0, const: Bool = false) -> String {
        let expression = castName + "(" + e + ")"
        return expression
    }
}

/// Return a known or new type reference for a given name and C type
/// - Parameters:
///   - identifier: The identifier of this type reference
///   - name: The name of the type
///   - swiftName: The name of the type to use in Swift (same as name if `nil`)
///   - typeName: The name of the underlying type (same as cType if `nil`)
///   - cType: The underlying C type
///   - isOptional: `true` if the reference is an optional
/// - Returns: A type reference
func typeReference(named identifier: String? = nil, for name: String, swiftName: String? = nil, typeName: String? = nil, cType: String, isOptional: Bool = false) -> TypeReference {
    let info = decodeIndirection(for: cType)
    let maybeType = GIR.namedTypes[name]?.first { $0.ctype == info.innerType }
    let type = maybeType ?? GIRType(name: name, swiftName: swiftName, typeName: typeName, ctype: info.innerType)
    let t = addType(type)
    return TypeReference(type: t, identifier: identifier, isConst: info.isConst, isOptional: isOptional, constPointers: info.indirection)
}

/// Add a new type to the list of known types
/// - Parameter type: The type to add
/// - Returns: An existing type matching the new type, or the passed in type if new
@inlinable
func addType(_ type: GIRType) -> GIRType {
    if let i = GIR.knownTypes.firstIndex(of: type) {
        return GIR.knownTypes[i]
    }
    GIR.knownTypes.insert(type)
    addKnownType(type, to: &GIR.namedTypes)
    return type
}


/// Add a known type to the name -> type mappings
/// - Parameter type: The type to add
/// - Returns: An existing type matching the new type, or the passed in type if new
@inlinable
func addKnownType(_ type: GIRType, to namedTypes: inout [String : Set<GIRType>]) {
    let name = type.name
    if namedTypes[name] == nil {
        namedTypes[name] = [type]
    } else {
        namedTypes[name]?.insert(type)
    }
}

/// Decode a C type and split into the elements required for a type reference
/// - Parameter cType: A string containing a type in C
/// - Returns: The inner type, whether the type is `const`, and the pointers (`true` if `const`) representing the indirection levels
func decodeIndirection<S: StringProtocol>(for cType: S) -> (innerType: String, isConst: Bool, indirection: [Bool]) {
    let s = cType.trimmingCharacters(in: .whitespacesAndNewlines).typeWithoutLeadingOrTrailingVolatile
    let const = s.hasPrefix("const")
    guard !const else {
        let si = s.index(s.startIndex, offsetBy: 5)
        let rv = decodeIndirection(for: s[si..<s.endIndex])
        return (rv.innerType, isConst: true, rv.indirection)
    }
    guard !s.hasSuffix("*") else {
        let ei = s.index(before: s.endIndex)
        let rv = decodeIndirection(for: s[s.startIndex..<ei])
        return (rv.innerType, isConst: rv.isConst, [false] + rv.indirection)
    }
    guard !s.hasSuffix("const") else {
        let ei = s.index(s.endIndex, offsetBy: -5)
        let rv = decodeIndirection(for: s[s.startIndex..<ei])
        let indirection: [Bool]
        if rv.indirection.isEmpty {
            indirection = [true]
        } else {
            indirection = rv.indirection[rv.indirection.startIndex..<rv.indirection.index(before: rv.indirection.endIndex)] + [true]
        }
        return (rv.innerType, isConst: rv.isConst, indirection)
    }
    return (innerType: s, isConst: false, indirection: [])
}
