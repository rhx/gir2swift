//
//  girtypereference.swift
//  libgir2swift
//
//  Created by Rene Hexel on 26/7/20.
//  Copyright © 2020 Rene Hexel. All rights reserved.
//
import Foundation

/// Reference to a GIR type.
public struct TypeReference: Hashable {
    /// The type referenced
    public let type: GIRType

    /// The identifier of this instance
    public let identifier: String?

    /// Whether or not the referenced type is `const`
    public var isConst: Bool = false

    /// Whether or not the referenced type is optional (nullable)
    public var isOptional: Bool = false

    /// Whether or not the referenced type is an array
    public var isArray: Bool = false

    /// Array of pointers (`true` if they are const, `false` if they are mutable)
    public var constPointers = [Bool]()

    /// Return an equivalent type reference from the current namespace
    @inlinable public var prefixed: TypeReference {
        let prefixedType = type.prefixed
        guard prefixedType !== type else { return self }
        return TypeReference(type: prefixedType, identifier: identifier, isConst: isConst, isOptional: isOptional, isArray: isArray, constPointers: constPointers)
    }

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
        let typeName = type.typeName.validSwift
        let raw = embeddedType(named: typeName)
        let full = raw.validFullSwift
        return full
    }

    /// returns the full type including pointers and  taking into account `const`
    @inlinable public var fullUnderlyingTypeName: String {
        let typeName = type.typeName.validSwift.optionalWhenCallback
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
        guard !name.hasSuffix("!") && !name.hasSuffix("?") else { return name }
        return name + "!"
    }

    /// returns the full Swift type (e.g. class) including pointers and  taking into account `const`
    public var fullSwiftTypeName: String {
        let typeName = type.swiftName.validSwift
        let raw = embeddedType(named: typeName)
        let full = raw.validFullSwift
        return full
    }

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
        // FIXME: this needs to check if this is a const -> mutating pointer cast
        let cast = type.cast(expression: e, from: source.type, pointerLevel: p, const: isConst)
        return cast
    }

    /// Reference to void type
    public static var void: TypeReference = TypeReference(type: GIR.voidType)

    /// Designated initialiser for a type reference
    /// - Parameters:
    ///   - type: The type to reference
    ///   - identifier: The identifier for this instance (e.g. C enum case name)
    ///   - isConst: Whether or not this reference is to a `const` instance
    ///   - isArray: Whether or not this is an array
    ///   - isOptional: Whether or not this instance is nullable
    ///   - constPointers: Array of booleans representing indirection levels (pointers), `true` if the pointer is `const`
    @inlinable
    public init(type: GIRType, identifier: String? = nil, isConst: Bool = false, isOptional: Bool = false, isArray: Bool = false, constPointers: [Bool] = []) {
        self.type = type
        self.identifier = identifier?.isEmpty ?? true ? nil : identifier
        self.isConst = isConst
        self.isOptional = isOptional
        self.isArray = isArray
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
        guard let supertype = self.type.parent else { return false }
        return self.type.isAlias && supertype.references(type)
    }

    /// Test whether the receiver references the given type reference
    /// - Parameter ref: The type reference to test for
    /// - Returns: `true` if the receiver references the given type reference
    @inlinable
    public func references(_ ref: TypeReference) -> Bool {
        if self.type === ref.type && self.indirectionLevel >= ref.indirectionLevel { return true }
        guard let supertype = self.type.parent else { return false }
        return self.type.isAlias && supertype.references(type)
    }

    /// Test whether the receiver is a pointer at some level to the given type
    /// - Parameter type: The type to test for
    /// - Returns: `true` if the receiver is some pointer to the given type
    @inlinable
    public func isSomePointer(to type: GIRType) -> Bool {
        if self.type === type && indirectionLevel > 0 { return true }
        guard let supertype = self.type.parent else { return false }
        return self.type.isAlias && supertype.isSomePointer(to: type)
    }

    /// Test whether the receiver is a pointer at some level to the given type reference
    /// - Parameter ref: The type reference to test for
    /// - Returns: `true` if the receiver is some pointer to the given type reference
    @inlinable
    public func isSomePointer(to ref: TypeReference) -> Bool {
        if self.type === ref.type && self.indirectionLevel > ref.indirectionLevel { return true }
        guard let supertype = self.type.parent else { return false }
        return self.type.isAlias && supertype.isSomePointer(to: type)
    }

    /// Test whether the receiver is a direct pointer to the given type
    /// - Parameter type: The type to test for
    /// - Returns: `true` if the receiver  is a direct pointer to the given type
    @inlinable
    public func isDirectPointer(to type: GIRType) -> Bool {
        if self.type === type && indirectionLevel == 1 { return true }
        guard let supertype = self.type.parent else { return false }
        return self.type.isAlias && supertype.isDirectPointer(to: type)
    }

    /// Test whether the receiver is a direct pointer to the given type reference
    /// - Parameter ref: The type reference to test for
    /// - Returns: `true` if the receiver  is a direct pointer to the given type reference
    @inlinable
    public func isDirectPointer(to ref: TypeReference) -> Bool {
        if self.type === ref.type && self.indirectionLevel == ref.indirectionLevel + 1 { return true }
        guard let supertype = self.type.parent else { return false }
        return self.type.isAlias && supertype.isDirectPointer(to: type)
    }

    /// Test whether the receiver is an alias of the given type
    /// - Parameter type: The type to test for
    /// - Returns: `true` if the receiver is an alias of the passed-in type
    @inlinable
    public func isAlias(of type: GIRType) -> Bool {
        if self.type === type && indirectionLevel == 0 { return true }
        guard let supertype = self.type.parent else { return false }
        return self.type.isAlias && supertype.isAlias(of: type)
    }

    /// Test whether the receiver is an alias of the given type reference
    /// - Parameter ref: The type reference to test for
    /// - Returns: `true` if the receiver is an alias of the passed-in type
    @inlinable
    public func isAlias(of ref: TypeReference) -> Bool {
        if self.type === ref.type && indirectionLevel == ref.indirectionLevel { return true }
        guard let supertype = self.type.parent else { return false }
        return self.type.isAlias && supertype.isAlias(of: ref)
            || ref.type.isAlias && ref.type.parent.map { isAlias(of: $0) } ?? false
    }
}

