//
//  girtypereference.swift
//  libgir2swift
//
//  Created by Rene Hexel on 26/7/20.
//  Copyright © 2020, 2022 Rene Hexel. All rights reserved.
//
import Foundation

/// Reference to a GIR type.
public struct TypeReference: Hashable {
    /// The type referenced
    public let type: GIRType

    /// The identifier of this instance
    public let identifier: String?

    /// The namespace for this instance
    public let namespace: String

    /// Whether or not the referenced type is `const`
    public var isConst: Bool = false

    /// Whether or not the referenced type is optional (nullable)
    public var isOptional: Bool = false

    /// Whether or not the referenced type is an array
    public var isArray: Bool = false

    /// Array of pointers (`true` if they are const, `false` if they are mutable)
    public var constPointers = [Bool]()

    /// The level of indirection,
    /// with `0` indicating the referenced type itself,
    /// `1` representing a pointer to an instance of the referenced type,
    /// `2` representing an array of pointers (or a pointer to a pointer), etc.
    @inlinable public var indirectionLevel: Int { constPointers.count }

    /// Returns `true` if the receiver is a reference to `void`
    @inlinable public var isVoid: Bool { return isAlias(of: .void) }

    /// returns the full C type including pointers and `const`
    @inlinable public var fullCType: String {
        var ct = type.ctype + (constPointers.isEmpty ? "" : " ")
        for e in constPointers.enumerated() {
            ct = ct + (e.element || (e.offset == 0 && isConst) ? "const*" : "*")
        }
        return ct
    }

    /// returns the full type including pointers and  taking into account `const`
    @inlinable public var fullTypeName: String {
        return fullUnderlyingTypeName(asOptional: false)
    }

    /// returns the full type including pointers and  taking into account `const`
    /// - Parameters:
    ///   - isOptional: return an optional if `true`, otherwise will return an optional if a callback only
    /// - Returns: Full type, including pointers and taking into account `const`
    @inlinable public func fullUnderlyingTypeName(asOptional: Bool? = nil) -> String {
        let swiftType = type.typeName.validSwift
        let typeName = (asOptional ?? swiftType.maybeCallback ) ? swiftType.asOptional : swiftType
        let raw = embeddedType(named: typeName)
        let full = raw.validFullSwift
        return full
    }

    /// returns the full C type including pointers and  taking into account `const`
    @inlinable public var fullUnderlyingCName: String {
        let typeName = type.ctype.validSwift
        let raw = embeddedType(named: typeName)
        let full = raw.validFullSwift
        return full
    }

    /// returns the force-unwrapped, full type name
    @inlinable public var forceUnwrappedName: String {
        let name = fullTypeName
        guard !name.isOptional else { return name }
        return name + "!"
    }

    /// returns the full Swift type (e.g. class) including pointers and  taking into account `const`
    public var fullSwiftTypeName: String {
        let typeName = type.swiftName.validSwift
        let raw = embeddedType(named: typeName)
        let full = raw.validFullSwift
        return full
    }

    /// Embed the given type in a layer of pointers as appropriate
    /// - Parameters:
    ///   - name: The inner type to wrap
    ///   - makeInnermostOptional: make the innermost type an optional if `true`
    /// - Returns: The type wrapped in pointers as appropriate
    public func embeddedType(named name: String) -> String {
        let k = constPointers.count - 1
        let prefix = (isArray ? "[" : "") + constPointers.enumerated().map {
            let i = min(k, $0.offset+1)
            let elementIsConst = ($0.offset == k && isConst) || constPointers[i]
            let element = "Unsafe" + (elementIsConst ? "" : "Mutable") + "Pointer<"
            return element
        }.joined()
        let innerSuffix: String
        if constPointers.count <= 1 {
            innerSuffix = ""
        } else {
            let s = constPointers.startIndex
            let e = constPointers.index(before: constPointers.endIndex)
            innerSuffix = constPointers[s..<e].map { _ in ">?" }.joined()
        }
        let outerSuffix = constPointers.isEmpty ? "" : (">" + (isOptional ? "?" : "!"))
        let suffix = innerSuffix + outerSuffix + (isArray ? "]" : "")
        let st = prefix + name + suffix
        return st
    }

    /// Cast from one type reference to another
    /// - Parameters:
    ///   - expression: The expression to cast
    ///   - source: The source type reference to cast from
    /// - Returns: The expression cast to the receiver type
    @inlinable public func cast(expression e: String, from source: TypeReference) -> String {
        guard self != source && (constPointers != source.constPointers || source.type.name != (type.name + "!")) else { return e }
        let p = indirectionLevel == 0 ? 0 : max(1, indirectionLevel - source.indirectionLevel)
        let cast = type.cast(expression: e, from: source.type, pointerLevel: p, const: isConst, isConstSource: source.isConst)
        return cast
    }

    /// Reference to void type
    public static var void: TypeReference = TypeReference(type: GIR.voidType)

    /// Designated initialiser for a type reference
    /// - Parameters:
    ///   - type: The type to reference
    ///   - namespace: The namespace to use, `nil` to use referenced type namespace
    ///   - identifier: The identifier for this instance (e.g. C enum case name)
    ///   - isConst: Whether or not this reference is to a `const` instance
    ///   - isArray: Whether or not this is an array
    ///   - isOptional: Whether or not this instance is nullable
    ///   - constPointers: Array of booleans representing indirection levels (pointers), `true` if the pointer is `const`
    @inlinable
    public init(type: GIRType, in namespace: String? = nil, identifier: String? = nil, isConst: Bool = false, isOptional: Bool = false, isArray: Bool = false, constPointers: [Bool] = []) {
        self.type = type
        self.identifier = identifier?.isEmpty ?? true ? nil : identifier
        self.namespace = namespace ?? type.namespace
        self.isConst = isConst
        self.isOptional = isOptional
        self.isArray = isArray
        self.constPointers = constPointers
    }

    /// Create a single-indirection pointer to a given target
    /// - Parameter target: The target type to reference
    /// - Parameter namespace: The name space to use, `nil` if top level
    /// - Parameter isConst: Whether the target is `const`
    /// - Parameter pointerIsConst:Whether the pointer itself is `const`
    /// - Returns: A type reference representing a pointer to the target
    public static func pointer(to target: GIRType, in namespace: String? = nil, isConst const: Bool = false, pointerIsConst: Bool = false) -> TypeReference {
        TypeReference(type: target, in: namespace, isConst: const, constPointers: [pointerIsConst])
    }

    /// Test whether the receiver references the given type
    /// - Parameter otherType: The type to test for
    /// - Returns: `true` if the receiver references the given type
    @inlinable
    public func references(_ otherType: GIRType) -> Bool {
        if type === otherType { return true }
        guard type.isAlias, let supertype = type.parent else {
            guard otherType.isAlias, let supertype = otherType.parent else { return false }
            return references(supertype)
        }
        return supertype.references(otherType)
    }

    /// Test whether the receiver references the given type reference
    /// - Parameter ref: The type reference to test for
    /// - Returns: `true` if the receiver references the given type reference
    @inlinable
    public func references(_ ref: TypeReference) -> Bool {
        if type === ref.type && self.indirectionLevel >= ref.indirectionLevel { return true }
        guard type.isAlias, let supertype = type.parent else {
            guard ref.type.isAlias, let supertype = ref.type.parent else { return false }
            return isSomePointer(to: supertype)
        }
        return supertype.references(ref.type)
    }

    /// Test whether the receiver is a pointer at some level to the given type
    /// - Parameter otherType: The type to test for
    /// - Returns: `true` if the receiver is some pointer to the given type
    @inlinable
    public func isSomePointer(to otherType: GIRType) -> Bool {
        if type === otherType && indirectionLevel > 0 { return true }
        guard type.isAlias, let supertype = type.parent else {
            guard otherType.isAlias, let supertype = otherType.parent else { return false }
            return isSomePointer(to: supertype)
        }
        return supertype.isSomePointer(to: otherType)
    }

    /// Test whether the receiver is a pointer at some level to the given type reference
    /// - Parameter ref: The type reference to test for
    /// - Returns: `true` if the receiver is some pointer to the given type reference
    @inlinable
    public func isSomePointer(to ref: TypeReference) -> Bool {
        if type === ref.type && indirectionLevel > ref.indirectionLevel { return true }
        guard let supertype = type.parent else {
            guard ref.type.isAlias, let supertype = ref.type.parent else { return false }
            return isSomePointer(to: supertype)
        }
        return type.isAlias && supertype.isSomePointer(to: ref.type)
    }

    /// Test whether the receiver is a direct pointer to the given type
    /// - Parameter otherType: The type to test for
    /// - Returns: `true` if the receiver  is a direct pointer to the given type
    @inlinable
    public func isDirectPointer(to otherType: GIRType) -> Bool {
        if type === otherType && indirectionLevel == 1 { return true }
        guard type.isAlias, let supertype = type.parent else {
            guard otherType.isAlias, let supertype = otherType.parent else { return false }
            return isDirectPointer(to: supertype)
        }
        return supertype.isDirectPointer(to: otherType)
    }

    /// Test whether the receiver is a direct pointer to the given type reference
    /// - Parameter ref: The type reference to test for
    /// - Returns: `true` if the receiver  is a direct pointer to the given type reference
    @inlinable
    public func isDirectPointer(to ref: TypeReference) -> Bool {
        if type === ref.type && indirectionLevel == ref.indirectionLevel + 1 { return true }
        guard type.isAlias, let supertype = type.parent else {
            guard ref.type.isAlias, let supertype = ref.type.parent else { return false }
            return isDirectPointer(to: supertype)
        }
        return supertype.isDirectPointer(to: ref.type)
    }

    /// Test whether the receiver is an alias of the given type
    /// - Parameter otherType: The type to test for
    /// - Returns: `true` if the receiver is an alias of the passed-in type
    @inlinable
    public func isAlias(of otherType: GIRType) -> Bool {
        if type === otherType && indirectionLevel == 0 { return true }
        guard type.isAlias, let supertype = type.parent else {
            guard otherType.isAlias, let supertype = otherType.parent else { return false }
            return isAlias(of: supertype)
        }
        return supertype.isAlias(of: otherType)
    }

    /// Test whether the receiver is an alias of the given type reference
    /// - Parameter ref: The type reference to test for
    /// - Returns: `true` if the receiver is an alias of the passed-in type
    @inlinable
    public func isAlias(of ref: TypeReference) -> Bool {
        if type === ref.type && indirectionLevel == ref.indirectionLevel { return true }
        guard let supertype = type.parent else {
            guard ref.type.isAlias, let supertype = ref.type.parent else { return false }
            return isAlias(of: supertype)
        }
        return type.isAlias && supertype.isAlias(of: ref)
            || ref.type.isAlias && ref.type.parent.map { isAlias(of: $0) } ?? false
    }
}

