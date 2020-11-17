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

    /// an enumeration entry
    public class Enumeration: Datatype {
        /// String representation of `Enumeration`s
        public override var kind: String { return "Enumeration" }
        /// an enumeration value in C is a constant
        public typealias Member = Constant

        /// enumeration values
        public let members: [Member]

        /// Designated initialiser
        /// - Parameters:
        ///   - name: The name of the `Enumeration` to initialise
        ///   - type: C typedef name of the enum
        ///   - members: the cases for this enum
        ///   - comment: Documentation text for the enum
        ///   - introspectable: Set to `true` if introspectable
        ///   - deprecated: Documentation on deprecation status if non-`nil`
        public init(name: String, type: TypeReference, members: [Member], comment: String, introspectable: Bool = false, deprecated: String? = nil) {
            self.members = members
            super.init(name: name, type: type, comment: comment, introspectable: introspectable, deprecated: deprecated)
        }

        /// Initialiser to construct an enumeration from XML
        /// - Parameters:
        ///   - node: `XMLElement` to construct this enum from
        ///   - index: Index within the siblings of the `node`
        public init(node: XMLElement, at index: Int) {
            let mem = node.children.lazy.filter { $0.name == "member" }
            members = mem.enumerated().map { Member(node: $0.1, at: $0.0) }
            super.init(node: node, at: index)
        }

        /// Register this type as an enumeration type
        @inlinable
        override public func registerKnownType() {
            if !GIR.enums.contains(typeRef.type) {
                GIR.enums.insert(typeRef.type)
            }
        }
    }
    
}

