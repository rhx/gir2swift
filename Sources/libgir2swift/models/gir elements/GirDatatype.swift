//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 17.11.2020.
//

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif
import SwiftLibXML

extension GIR {

    /// GIR type class
    public class Datatype: Thing {
        /// String representation of the `Datatype` thing
        public override var kind: String { return "Datatype" }
        /// The underlying type
        public var typeRef: TypeReference
        /// The identifier of this instance (e.g. C enum value type)
        @inlinable public var identifier: String? { typeRef.identifier }

        /// A reference to the underlying C type
        @inlinable public var underlyingCRef: TypeReference {
            let type = typeRef.type
            let nm = typeRef.fullCType
            let tp = GIRType(name: nm, ctype: type.ctype, superType: type.parent, isAlias: type.isAlias, conversions: type.conversions)
            let ref = TypeReference(type: tp, identifier: typeRef.identifier, isConst: typeRef.isConst, isOptional: typeRef.isOptional, isArray: typeRef.isArray, constPointers: typeRef.constPointers)
            return ref
        }

        /// Memberwise initialiser
        /// - Parameters:
        ///   - name: The name of the `Datatype` to initialise
        ///   - type: The corresponding, underlying GIR type
        ///   - comment: Documentation text for the data type
        ///   - introspectable: Set to `true` if introspectable
        ///   - deprecated: Documentation on deprecation status if non-`nil`
        ///   - version: The version this data type is first available in
        public init(name: String, type: TypeReference, comment: String, introspectable: Bool = false, deprecated: String? = nil) {
            typeRef = type
            super.init(name: name, comment: comment, introspectable: introspectable, deprecated: deprecated)
            registerKnownType()
        }

        /// XML Element initialser
        /// - Parameters:
        ///   - node: `XMLElement` to construct this data type from
        ///   - index: Index within the siblings of the `node`
        ///   - type: Type reference for the data type (taken from XML if `nil`)
        ///   - nameAttr: Key for the attribute to extract the `name` property from
        public init(node: XMLElement, at index: Int, with type: TypeReference? = nil, nameAttr: String = "name") {
            typeRef = type ?? node.alias
            super.init(node: node, at: index, nameAttr: nameAttr)
            typeRef.isArray = node.name == "array"
            registerKnownType()
        }

        /// Register this type as an enumeration type
        @inlinable
        public func registerKnownType() {
        }

        /// Returns `true` if the data type is `void`
        public var isVoid: Bool {
            return typeRef.isVoid
        }
    }
}
