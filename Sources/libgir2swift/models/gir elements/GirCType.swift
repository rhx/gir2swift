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

    /// a type with an underlying C type entry
    public class CType: Datatype {
        /// String representation of the `CType` thing
        public override var kind: String { return "CType" }
        /// list of contained types
        public let containedTypes: [CType]
        /// reference scope
        public let scope: String?
        /// `true` if this is a readable element
        public let isReadable: Bool
        /// `true` if this is a writable element
        public let isWritable: Bool
        /// `true` if this is a private element
        public let isPrivate: Bool
        /// tuple size if non-`nil`
        public let tupleSize: Int?

        /// Returns `true` if the data type is `void`
        public override var isVoid: Bool {
            return super.isVoid && (tupleSize ?? 0) == 0
        }

        /// Designated initialiser
        /// - Parameters:
        ///   - name: The name of the `Datatype` to initialise
        ///   - type: The corresponding, underlying GIR type
        ///   - comment: Documentation text for the data type
        ///   - introspectable: Set to `true` if introspectable
        ///   - deprecated: Documentation on deprecation status if non-`nil`
        ///   - isWritable: Set to `true` if this is a writable type
        ///   - contains: Array of C types contained within this type
        ///   - tupleSize: Size of the given tuple if non-`nil`
        ///   - scope: The scope this type belongs in
        public init(name: String, type: TypeReference, comment: String, introspectable: Bool = false, deprecated: String? = nil, isPrivate: Bool = false, isReadable: Bool = true, isWritable: Bool = false, contains: [CType] = [], tupleSize: Int? = nil, scope: String? = nil) {
            self.isPrivate  = isPrivate
            self.isReadable = isReadable
            self.isWritable = isWritable
            self.containedTypes = contains
            self.tupleSize = tupleSize
            self.scope = scope
            super.init(name: name, type: type, comment: comment, introspectable: introspectable, deprecated: deprecated)
        }

        /// XML Element initialser
        /// - Parameters:
        ///   - node: `XMLElement` to construct this C type from
        ///   - index: Index within the siblings of the `node`
        ///   - nameAttr: Key for the attribute to extract the `name` property from
        ///   - privateAttr:  Key for the attribute to extract the privacy status from
        ///   - readableAttr: Key for the attribute to extract the readbility status from
        ///   - writableAttr: Key for the attribute to extract the writability status from
        ///   - scopeAttr: Key for the attribute to extract the  scope string from
        public init(node: XMLElement, at index: Int, nameAttr: String = "name", privateAttr: String = "private", readableAttr: String = "readable", writableAttr: String = "writable", scopeAttr: String = "scope") {
            containedTypes = node.containedTypes
            isPrivate  = node.attribute(named: privateAttr) .flatMap({ Int($0) }).map({ $0 != 0 }) ?? false
            isReadable = node.attribute(named: readableAttr).flatMap({ Int($0) }).map({ $0 != 0 }) ?? true
            isWritable = node.attribute(named: writableAttr).flatMap({ Int($0) }).map({ $0 != 0 }) ?? false
            tupleSize = node.attribute(named: "fixed-size").flatMap(Int.init)
            scope = node.attribute(named: scopeAttr)
            super.init(node: node, at: index, nameAttr: nameAttr)
        }

        /// Factory method to construct a C Type from XML with types taken from children
        /// - Parameters:
        ///   - node: `XMLElement` whose descendants to construct this C type from
        ///   - index: Index within the siblings of the `node`
        ///   - nameAttr: Key for the attribute to extract the `name` property from
        ///   - typeAttr: Key for the attribute to extract the `type` property from
        ///   - scopeAttr: Key for the attribute to extract the  scope string from
        public init(fromChildrenOf node: XMLElement, at index: Int, nameAttr: String = "name", privateAttr: String = "private", readableAttr: String = "readable", writableAttr: String = "writable", scopeAttr: String = "scope") {
            let type: TypeReference
            isPrivate  = node.attribute(named: privateAttr) .flatMap({ Int($0) }).map({ $0 != 0 }) ?? false
            isReadable = node.attribute(named: readableAttr).flatMap({ Int($0) }).map({ $0 != 0 }) ?? true
            isWritable = node.attribute(named: writableAttr).flatMap({ Int($0) }).map({ $0 != 0 }) ?? false
            scope = node.attribute(named: scopeAttr)
            if let array = node.children.filter({ $0.name == "array" }).first {
                type = array.alias
                tupleSize = array.attribute(named: "fixed-size").flatMap(Int.init)
                containedTypes = array.containedTypes
            } else {
                containedTypes = []
                tupleSize = nil
                type = GIR.typeOf(node: node)
            }
            super.init(node: node, at: index, with: type, nameAttr: nameAttr)
        }

        /// return whether the type is an array
        @inlinable
        public var isArray: Bool { return !containedTypes.isEmpty }

        /// return whether the receiver is an instance of the given record (class)
        /// - Parameter record: The record to test for
        /// - Returns: `true` if `self` points to `record`
        @inlinable
        public func isInstanceOf(_ record: GIR.Record?) -> Bool {
            if let r = record?.typeRef, (isGPointer && typeRef.type.name == record?.name) || typeRef.isDirectPointer(to: r) {
                return true
            } else {
                return false
            }
        }

        /// return whether the type is a magical `gpointer` or related
        /// - Note: This returns `false` if the indirection level is non-zero (e.g. for a `gpointer *`)
        @inlinable
        public var isGPointer: Bool {
            guard typeRef.indirectionLevel == 0 else { return false }
            let type = typeRef.type
            let name = type.typeName
            return name == GIR.gpointer || name == GIR.gconstpointer
        }

        /// return whether the receiver is an instance of the given record (class) or any of its ancestors
        @inlinable
        public func isInstanceOfHierarchy(_ record: GIR.Record) -> Bool {
            if isInstanceOf(record) { return true }
            guard let parent = record.parentType else { return false }
            return isInstanceOfHierarchy(parent)
        }

        /// indicates whether the receiver is any known kind of pointer
        @inlinable
        public var isAnyKindOfPointer: Bool {
            guard typeRef.indirectionLevel == 0 else { return true }
            let type = typeRef.type
            let name = type.name
            return isGPointer || name.maybeCallback
        }

        /// indicates whether the receiver is an array of scalar values
        @inlinable
        public var isScalarArray: Bool { return isArray && !isAnyKindOfPointer }

        /// return the Swift camel case name, quoted if necessary
        @inlinable
        public var camelQuoted: String { name.camelCase.swiftQuoted }

        /// return a non-clashing argument name
        @inlinable
        public var nonClashingName: String {
            let sw = name.swift
            let nt = sw + (sw.isKnownType ? "_" : "")
            let type = typeRef.type
            let ctype = type.ctype
            let ct = ctype.innerCType.swiftType // swift name for C type
            let st = ctype.innerCType.swift     // corresponding Swift type
            let nc = nt == ct ? nt + "_" : nt
            let ns = nc == st ? nc + "_" : nc
            let na = ns == type.swiftName  ? ns + "_" : ns
            return na
        }

        //// return the known type of the argument (nil if not known)
        @inlinable
        public var knownType: GIR.Datatype? { return GIR.knownDataTypes[typeRef.type.name] }
        
        //// return the known class/record of the argument (nil if not known)
        @inlinable
        public var knownRecord: GIR.Record? {
            typeRef.knownIndirectionLevel == 1 ? GIR.knownRecords[typeRef.type.name] : nil
        }
        
        //// return the known bitfield the argument represents (nil if not known)
        @inlinable
        public var knownBitfield: GIR.Bitfield? { return GIR.knownBitfields[typeRef.type.name] }

        /// indicates whether the receiver is a known type
        @inlinable
        public var isKnownType: Bool { return knownType != nil }

        /// indicates whether the receiver is a known class or record
        @inlinable
        public var isKnownRecord: Bool { return knownRecord != nil }

        /// indicates whether the receiver is a known bit field
        @inlinable
        public var isKnownBitfield: Bool { return knownBitfield != nil }
        
        /// return the non-prefixed argument name
        @inlinable
        public var argumentName: String { return name.argumentSplit.arg.camelQuoted }
    }
}
