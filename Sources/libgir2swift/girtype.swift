//
//  girtype.swift
//  libgir2swift
//
//  Created by Rene Hexel on 18/7/20.
//  Copyright © 2020 Rene Hexel. All rights reserved.
//
import Foundation

/// Reference to a GIR type.
public struct TypeReference: Hashable {
    /// The type referenced
    public let type: GIRType

    /// Whether or not the referenced type is `const`
    public var isConst: Bool = false

    /// Array of pointers (`true` if they are false)
    public var constPointers = [Bool]()

    /// The level of indirection,
    /// with `0` indicating the referenced type itself,
    /// `1` representing a pointer to an instance of the referenced type,
    /// `2` representing an array of pointers (or a pointer to a pointer), etc.
    public var indirectionLevel: Int { constPointers.count }

    /// Reference to void type
    public static var void: TypeReference = TypeReference(type: GIR.voidType)

    /// Designated initialiser for a type reference
    /// - Parameters:
    ///   - type: The type to reference
    ///   - isConst: Whether or not this reference is to a `const` instance
    ///   - constPointers: Array of booleans representing indirection levels (pointers), `true` if the pointer is `const`
    @inlinable
    public init(type: GIRType, isConst: Bool = false, constPointers: [Bool] = []) {
        self.type = type
        self.isConst = isConst
        self.constPointers = constPointers
    }

    /// Create a single-indirection pointer to a given target
    /// - Parameter target: The target type to reference
    /// - Parameter isConst: Whether the target is `const`
    /// - Parameter pointerIsConst:Whether the pointer itself is `const`
    /// - Returns: A type reference representing a pointer to the target
    public static func pointer(to target: GIRType, isConst const: Bool = false, pointerIsConst: Bool = false) -> TypeReference {
        TypeReference(type: target, isConst: const, constPointers: [pointerIsConst])
    }

    /// Test whether the receiver references the given type
    /// - Parameter type: The type to test for
    /// - Returns: `true` if the receiver references the given type
    @inlinable
    public func references(_ type: GIRType) -> Bool {
        if self.type === type { return true }
        guard let supertype = self.type.isa else { return false }
        return self.type.isAlias && supertype.references(type)
    }

    /// Test whether the receiver references the given type reference
    /// - Parameter ref: The type reference to test for
    /// - Returns: `true` if the receiver references the given type reference
    @inlinable
    public func references(_ ref: TypeReference) -> Bool {
        if self.type === ref.type && self.indirectionLevel >= ref.indirectionLevel { return true }
        guard let supertype = self.type.isa else { return false }
        return self.type.isAlias && supertype.references(type)
    }

    /// Test whether the receiver is a pointer at some level to the given type
    /// - Parameter type: The type to test for
    /// - Returns: `true` if the receiver is some pointer to the given type
    @inlinable
    public func isSomePointer(to type: GIRType) -> Bool {
        if self.type === type && indirectionLevel > 0 { return true }
        guard let supertype = self.type.isa else { return false }
        return self.type.isAlias && supertype.isSomePointer(to: type)
    }

    /// Test whether the receiver is a pointer at some level to the given type reference
    /// - Parameter ref: The type reference to test for
    /// - Returns: `true` if the receiver is some pointer to the given type reference
    @inlinable
    public func isSomePointer(to ref: TypeReference) -> Bool {
        if self.type === ref.type && self.indirectionLevel > ref.indirectionLevel { return true }
        guard let supertype = self.type.isa else { return false }
        return self.type.isAlias && supertype.isSomePointer(to: type)
    }

    /// Test whether the receiver is a direct pointer to the given type
    /// - Parameter type: The type to test for
    /// - Returns: `true` if the receiver  is a direct pointer to the given type
    @inlinable
    public func isDirectPointer(to type: GIRType) -> Bool {
        if self.type === type && indirectionLevel == 1 { return true }
        guard let supertype = self.type.isa else { return false }
        return self.type.isAlias && supertype.isDirectPointer(to: type)
    }

    /// Test whether the receiver is a direct pointer to the given type reference
    /// - Parameter ref: The type reference to test for
    /// - Returns: `true` if the receiver  is a direct pointer to the given type reference
    @inlinable
    public func isDirectPointer(to ref: TypeReference) -> Bool {
        if self.type === ref.type && self.indirectionLevel == ref.indirectionLevel + 1 { return true }
        guard let supertype = self.type.isa else { return false }
        return self.type.isAlias && supertype.isDirectPointer(to: type)
    }

    /// Test whether the receiver is an alias of the given type
    /// - Parameter type: The type to test for
    /// - Returns: `true` if the receiver is an alias of the passed-in type
    @inlinable
    public func isAlias(of type: GIRType) -> Bool {
        if self.type === type && indirectionLevel == 0 { return true }
        guard let supertype = self.type.isa else { return false }
        return self.type.isAlias && supertype.isAlias(of: type)
    }

    /// Test whether the receiver is an alias of the given type reference
    /// - Parameter ref: The type reference to test for
    /// - Returns: `true` if the receiver is an alias of the passed-in type
    @inlinable
    public func isAlias(of ref: TypeReference) -> Bool {
        if self.type === ref.type && indirectionLevel == ref.indirectionLevel { return true }
        guard let supertype = self.type.isa else { return false }
        return self.type.isAlias && supertype.isAlias(of: ref)
            || ref.type.isAlias && ref.type.isa.map { isAlias(of: $0) } ?? false
    }
}

/// Representation of a fundamental type, its relationship to other types,
/// and casting operations
public class GIRType: Hashable {
    /// Name of the type defined in the GIR file
    public let name: String
    /// Name of the type in Swift
    public var swiftName: String
   /// Name of the type in C
    public let ctype: String
    /// The supertype (or equivalent, if alias) of this type
    public let isa: TypeReference?
    /// Indicatow whether this type is an alias that doesn't need casting
    public let isAlias: Bool
    /// Dictionary of possible type conversion (cast) operations to target types
    public var conversions: [GIRType : TypeConversion] = [:]

    /// Designated initialiser for a GIR type
    /// - Parameters:
    ///   - name: The name of the type
    ///   - swiftName: The name of the type in Swift (or `nil` if same as `name`)
    ///   - ctype: The name of the type in C
    ///   - superType: The parent or alias type (or `nil` if fundamental)
    ///   - isAlias: An indicator whether the type is an alias of its supertype that does not need casting
    @inlinable
    public init(name: String, swiftName: String? = nil, ctype: String, superType: TypeReference? = nil, isAlias: Bool = false) {
        precondition(isAlias == false || superType != nil)
        self.name = name
        self.swiftName = swiftName ?? name
        self.ctype = ctype
        self.isa = superType
        self.isAlias = isAlias
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
        self.init(name: name ?? t.name, swiftName: swiftName ?? t.swiftName, ctype: ctype ?? t.ctype, superType: typeReference, isAlias: true)
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

    /// Return the cast to convert the given expression to the target type
    /// - Parameters:
    ///   - expression: The expression to cast
    ///   - target: The target type to cast to
    /// - Returns: The cast expression string, or `nil` if there is no way to cast to `target`
    @inlinable
    public func cast(expression: String, to target: GIRType) -> String? {
        guard let conversion = conversions[target] else { return nil }
        return conversion.castToTarget(from: expression)
    }

    /// Return the cast to convert the given expression to the target type
    /// - Parameters:
    ///   - expression: The expression to cast
    ///   - source: The source type to cast from
    /// - Returns: The cast expression string, or `nil` if there is no way to cast from `source`
    @inlinable
    public func cast(expression e: String, from source: GIRType) -> String? {
        guard let conversion = conversions[source] else { return nil }
        return conversion.castFromTarget(expression: e)
    }

    /// Equality check for a type.
    /// Two types are considered equal if they have the same names and C types.
    /// - Parameters:
    ///   - lhs: The left hand side type to compare
    ///   - rhs: The right hand side type to compare
    /// - Returns: `true` if both types are considered equal
    @inlinable
    public static func == (lhs: GIRType, rhs: GIRType) -> Bool {
        return lhs.isAlias == rhs.isAlias && lhs.isa == rhs.isa && lhs.ctype == rhs.ctype
            && lhs.name == rhs.name && lhs.swiftName == rhs.swiftName
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
        hasher.combine(ctype)
        hasher.combine(isa)
        hasher.combine(isAlias)
    }
}

/// Type conversion operation.
/// This root class is used for aliases/equal type conversions,
/// i.e., casts are no-ops.
public class TypeConversion: Hashable {
    /// Source type
    public let source: GIRType
    /// Target type
    public let target: GIRType

    /// Designated initialiser for a type conversion
    /// - Parameter source: The source type for the conversion
    /// - Parameter target: The target type this conversion refers to
    @inlinable
    public init(source: GIRType, target: GIRType) {
        self.source = source
        self.target = target
    }

    /// Swift code for converting to the target type without cast.
    /// - Parameter expression: An expression of source type to cast to the target type
    @inlinable
    public func castToTarget(from expression: String) -> String {
        return "\(expression)"
    }

    /// Swift code for converting from the target type without cast.
    /// - Parameter expression: An expression of target type to cast to the source type
    @inlinable
    public func castFromTarget(expression: String) -> String {
        return "\(expression)"
    }

    /// Equality check for a type conversion.
    /// Two conversions are considered equal if they have the same name and C type.
    /// - Parameters:
    ///   - lhs: The left hand side type to compare
    ///   - rhs: The right hand side type to compare
    /// - Returns: `true` if both types are considered equal
    @inlinable
    public static func == (lhs: TypeConversion, rhs: TypeConversion) -> Bool {
        return lhs.source == rhs.source && lhs.target == rhs.target
    }

    /// Hashes the essential components of this type cast by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(source)
        hasher.combine(target)
    }
}

public class CastConversion: TypeConversion {
    /// Swift code for converting to the target type.
    /// By default, the type conversion is just a conversion constructor call.
    /// - Parameter expression: An expression of source type to cast to the target type
    @inlinable
    override public func castToTarget(from expression: String) -> String {
        return "\(target.name)(\(expression))"
    }

    /// Swift code for converting from the target type to the source type.
    /// By default, the type conversion is just a conversion constructor call.
    /// - Parameter expression: An expression of target type to cast to the source type
    @inlinable
    override public func castFromTarget(expression: String) -> String {
        return "\(source.name)(\(expression))"
    }
}

/// Parent/Child class conversion operation
public class SubClassConversion: TypeConversion {
    /// Swift code for converting to the target type using `as`.
    /// - Parameter expression: An expression of source type to cast to the target type
    @inlinable
    override public func castToTarget(from expression: String) -> String {
        return "(\(expression)) as \(target.name)"
    }

    /// Swift code for converting from the target type to the source type
    /// using `as!`.
    /// - Parameter expression: An expression of target type to cast to the source type
    @inlinable
    override public func castFromTarget(expression: String) -> String {
        return "(\(expression)) as! \(source.name)"
    }
}

/// Parent/Child class conversion operation with optional upcast
public class OptionalSubClassConversion: SubClassConversion {
    /// Swift code for optional conversion from the target type to the source type
    /// using `as?`.
    /// - Parameter expression: An expression of target type to cast to the source type
    @inlinable
    override public func castFromTarget(expression: String) -> String {
        return "(\(expression)) as? \(source.name)"
    }
}

/// Custom type conversion operation
public class CustomConversion: TypeConversion {
    /// The prefix to apply when downcasting an expression
    public let downcastPrefix: String
    /// The suffix to apply when downcasting an expression
    public let downcastSuffix: String
    /// The prefix to apply when upcasting an expression
    public let upcastPrefix: String
    /// The suffix to apply when upcasting an expression
    public let upcastSuffix: String

    /// Designated initialiser for a custom type conversion
    /// - Parameter source: The source type for the conversion
    /// - Parameter target: The target type this conversion refers to
    /// - Parameter downPrefix:The prefix to apply when downcasting an expression
    /// - Parameter downSuffix: The suffix to apply when downcasting an expression
    /// - Parameter upPrefix: The prefix to apply when upcasting an expression
    /// - Parameter upSuffix: The suffix to apply when upcasting an expression
    @inlinable
    public init(source: GIRType, target: GIRType, downPrefix: String, downSuffix: String, upPrefix: String, upSuffix: String) {
        downcastPrefix = downPrefix
        downcastSuffix = downSuffix
        upcastPrefix = upPrefix
        upcastSuffix = upSuffix
        super.init(source: source, target: target)
    }

    /// Swift code for converting to the target type using the downcast prefix.
    /// - Parameter expression: An expression of source type to cast to the target type
    @inlinable
    override public func castToTarget(from expression: String) -> String {
        return downcastPrefix + expression + downcastSuffix
    }

    /// Swift code for converting to the target type using the upcast prefix.
    /// - Parameter expression: An expression of target type to cast to the source type
    @inlinable
    override public func castFromTarget(expression: String) -> String {
        return upcastPrefix + expression + upcastSuffix
    }
}


/// Nested type conversion operation
public class NestedConversion: CustomConversion {
    /// Nested inner conversion to apply to a type
    public var innerConversion: TypeConversion

    /// Designated initialiser for a nested type conversion
    /// - Parameter source: The source type for the conversion
    /// - Parameter target: The target type this conversion refers to
    /// - Parameter downPrefix:The prefix to apply when downcasting an expression
    /// - Parameter downSuffix: The suffix to apply when downcasting an expression
    /// - Parameter upPrefix: The prefix to apply when upcasting an expression
    /// - Parameter upSuffix: The suffix to apply when upcasting an expression
    /// - Parameter embedding: The type conversion to embed
    @inlinable
    public init(source: GIRType, target: GIRType, downPrefix: String, downSuffix: String, upPrefix: String, upSuffix: String, embedding: TypeConversion) {
        innerConversion = embedding
        super.init(source: source, target: target, downPrefix: downPrefix, downSuffix: downSuffix, upPrefix: upPrefix, upSuffix: upSuffix)
    }
}

public extension GIR {
    static let voidType = GIRType(name: "Void", ctype: "void")

    static let floatType   = GIRType(name: "Float", ctype: "float")
    static let doubleType  = GIRType(name: "Double", ctype: "double")
    static let float80Type = GIRType(name: "Float80", ctype: "long double")
    static let intType     = GIRType(name: "Int", ctype: "long")
    static let uintType    = GIRType(name: "UInt", ctype: "unsigned long")
    static let int8Type    = GIRType(name: "Int8", ctype: "int8_t")
    static let int16Type   = GIRType(name: "Int16", ctype: "int16_t")
    static let int32Type   = GIRType(name: "Int32", ctype: "int32_t")
    static let int64Type   = GIRType(name: "Int64", ctype: "int64_t")
    static let uint8Type   = GIRType(name: "UInt8", ctype: "u_int8_t")
    static let uint16Type  = GIRType(name: "UInt16", ctype: "u_int16_t")
    static let uint32Type  = GIRType(name: "UInt32", ctype: "u_int32_t")
    static let uint64Type  = GIRType(name: "UInt64", ctype: "u_int64_t")
    static let swiftNumericTypes: Set<GIRType> = [floatType, doubleType, float80Type, intType, uintType, int8Type, int16Type, int32Type, int64Type, uint8Type, uint16Type, uint32Type, uint64Type]

    static let cintType     = GIRType(name: "CInt", ctype: "int")
    static let clongType    = GIRType(name: "CLong", ctype: "long")
    static let cshortType   = GIRType(name: "CShort", ctype: "short")
    static let cboolType    = GIRType(name: "CBool", ctype: "bool")
    static let ccharType    = GIRType(name: "CChar", ctype: "char")
    static let cscharType   = GIRType(name: "CSignedChar", ctype: "signed char")
    static let cuintType    = GIRType(name: "CUnsignedInt", ctype: "unsigned int")
    static let culongType   = GIRType(name: "CUnsignedLong", ctype: "unsigned long")
    static let cushortType  = GIRType(name: "CUnsignedShort", ctype: "unsigned short")
    static let cucharType   = GIRType(name: "CUnsignedChar", ctype: "unsigned char")
    static let cfloatType   = GIRType(name: "CFloat", ctype: "float")
    static let cdoubleType  = GIRType(name: "CDouble", ctype: "double")
    static let cldoubleType = GIRType(name: "CLongDouble", ctype: "long double")
    static let cNumericTypes: Set<GIRType> = [cintType, clongType, cshortType, cboolType, ccharType, cscharType, cuintType, culongType, cushortType, cucharType, cfloatType, cdoubleType, cldoubleType]

    static let gfloatType  = GIRType(name: "gfloat", ctype: "gfloat")
    static let gdoubleType = GIRType(name: "gdouble", ctype: "gdouble")
    static let gcharType   = GIRType(name: "gchar", ctype: "gchar")
    static let gintType    = GIRType(name: "gint", ctype: "gint")
    static let glongType   = GIRType(name: "glong", ctype: "glong")
    static let gshortType  = GIRType(name: "gshort", ctype: "gshort")
    static let gucharType  = GIRType(name: "guchar", ctype: "guchar")
    static let guintType   = GIRType(name: "guint", ctype: "guint")
    static let gulongType  = GIRType(name: "gulong", ctype: "gulong")
    static let gushortType = GIRType(name: "gushort", ctype: "gushort")
    static let gint8Type   = GIRType(name: "gint8", ctype: "gint8")
    static let gint16Type  = GIRType(name: "gint16", ctype: "gint16")
    static let gint32Type  = GIRType(name: "gint32", ctype: "gint32")
    static let gint64Type  = GIRType(name: "gint64", ctype: "gint64")
    static let guint8Type  = GIRType(name: "guint8", ctype: "guint8")
    static let guint16Type = GIRType(name: "guint16", ctype: "guint16")
    static let guint32Type = GIRType(name: "guint32", ctype: "guint32")
    static let guint64Type = GIRType(name: "guint64", ctype: "guint64")
    static let gsizeType   = GIRType(name: "gsize", ctype: "gsize")
    static let goffsetType = GIRType(name: "goffset", ctype: "goffset")
    static let gbooleanType = GIRType(name: "gboolean", ctype: "gboolean")
    static let glibNumericTypes: Set<GIRType> = [gfloatType, gdoubleType, gcharType, gintType, glongType, gshortType, gucharType, guintType, gulongType, gushortType, gint8Type, gint16Type, gint32Type, gint64Type, guint8Type, guint16Type, guint32Type, guint64Type, gsizeType, gbooleanType]

    static let numericTypes = swiftNumericTypes ∪ cNumericTypes ∪ glibNumericTypes

    static var boolType: GIRType = {
        let b = GIRType(name: "Bool", ctype: "bool")
        let p = "(("
        let s = ") != 0)"
        numericTypes.forEach { type in
            let tp = type.name + "(("
            let ts = ") ? 1 : 0)"
            type.conversions = Dictionary(uniqueKeysWithValues: numericConversions.filter {
                $0.source == type
            }.map { ($0.target, $0) } + [
                (b, CustomConversion(source: type, target: b, downPrefix: p, downSuffix: s, upPrefix: tp, upSuffix: ts))
            ])
            b.conversions[type] = CustomConversion(source: b, target: type, downPrefix: tp, downSuffix: ts, upPrefix: p, upSuffix: s)
        }
        return b
    }()

    static let charPtr = TypeReference.pointer(to: ccharType)
    static let constCharPtr = TypeReference.pointer(to: ccharType, isConst: true)
    static let gcharPtr = TypeReference.pointer(to: gcharType)
    static let constGCharPtr = TypeReference.pointer(to: gcharType, isConst: true)
    static let gucharPtr = TypeReference.pointer(to: gucharType)
    static let constGUCharPtr = TypeReference.pointer(to: gucharType, isConst: true)
    static let stringType = GIRType(name: "utf8", swiftName: "String", ctype: "char", superType: charPtr)
    static let constStringType = GIRType(name: "utf8", swiftName: "String", ctype: "char", superType: constCharPtr)
    static let gstringType = GIRType(name: "utf8", swiftName: "String", ctype: "gchar", superType: gcharPtr)
    static let constGStringType = GIRType(name: "utf8", swiftName: "String", ctype: "gchar", superType: gcharPtr)
    static let gustringType = GIRType(name: "utf8", swiftName: "String", ctype: "guchar", superType: gucharPtr)
    static let constGUStringType = GIRType(name: "utf8", swiftName: "String", ctype: "guchar", superType: constGUCharPtr)

    static let stringTypes: Set<GIRType> = [stringType, constStringType, gstringType, constGStringType, gustringType, constGUStringType]

    /// Common aliases used
    static var aliases: Set<GIRType> = {[
        GIRType(aliasOf: guintType, ctype: "unsigned int"),
        GIRType(aliasOf: gulongType, ctype: "unsigned long"),
        GIRType(aliasOf: gushortType, ctype: "unsigned short"),
        GIRType(aliasOf: guint8Type, ctype: "unsigned char"),
    ]}()

    /// All fundamental types prior to GIR parsing
    static var fundamentalTypes: Set<GIRType> = {
        return numericTypes ∪ boolType ∪ voidType ∪ stringType ∪ aliases
    }()

    /// All numeric conversions
    static var numericConversions = { numericTypes.flatMap { s in numericTypes.map { t in
        s == t ? TypeConversion(source: s, target: t) : CastConversion(source: s, target: t)
    }}}()

    /// All known types so far
    static var knownTypes: Set<GIRType> = fundamentalTypes

    /// Mapping from names to known types
    static var namedTypes: [String : Set<GIRType>] = {
        var namedTypes = [String : Set<GIRType>]()
        knownTypes.forEach { addKnownType($0, to: &namedTypes) }
        return namedTypes
    }()
}

/// Return a known or new type reference for a given name and C type
/// - Parameters:
///   - name: The name of the type
///   - cType: The underlying C type
/// - Returns: A type reference
func typeReference(for name: String, cType: String) -> TypeReference {
    let info = decodeIndirection(for: cType)
    let maybeType = GIR.namedTypes[name]?.first { $0.ctype == info.innerType }
    let type = maybeType ?? GIRType(name: name, ctype: info.innerType)
    let t = addType(type)
    return TypeReference(type: t, isConst: info.isConst, constPointers: info.indirection)
}

/// Add a new type to the list of known types
/// - Parameter type: The type to add
/// - Returns: An existing type matching the new type, or the passed in type if new
@inlinable
func addType(_ type: GIRType) -> GIRType {
    if let i = GIR.knownTypes.index(of: type) {
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
    let s = cType.trimmingCharacters(in: .whitespacesAndNewlines)
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
