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

    /// a data type record to create a protocol/struct/class for
    public class Record: CType {
        /// String representation of `Record`s
        public override var kind: String { return "Record" }
        /// C language symbol prefix
        public let cprefix: String
        /// C type getter function
        public let typegetter: String
        /// Methods associated with this record
        public let methods: [Method]
        /// Functions associated with this record
        public let functions: [Function]
        /// Constructors for this record
        public let constructors: [Method]
        /// Properties of this record
        public let properties: [Property]
        /// Fieldss of this record
        public let fields: [Field]
        /// List of signals for this record
        public let signals: [Signal]
        /// Type struct (e.g. class definition), typically nil for records
        public var typeStruct: String?
        /// Name of the function that returns the GType for this record (`nil` if unspecified)
        public var parentType: Record? { return nil }
        /// Root class (`nil` for plain records)
        public var rootType: Record { return self }
        /// Names of implemented interfaces
        public var implements: [String]
        /// records contained within this record
        public var records: [Record] = []

        /// return all functions, methods, and constructors
        public var allMethods: [Method] {
            return constructors + methods + functions
        }

        /// return all functions, methods, and constructors inherited from ancestors
        public var inheritedMethods: [Method] {
            guard let parent = parentType else { return [] }
            return parent.allMethods + parent.inheritedMethods
        }

        /// return the typed pointer name
        @inlinable public var ptrName: String { cprefix + "_ptr" }

        /// Designated initialiser
        /// - Parameters:
        ///   - name: The name of the record to initialise
        ///   - type: C typedef name of the constant
        ///   - ctype: underlying C type
        ///   - cprefix: prefix used for C language free functions that implement methods for this record
        ///   - typegetter: C type getter function
        ///   - methods: Methods associated with this record
        ///   - functions: Functions associated with this record
        ///   - constructors: Constructors for this record
        ///   - properties: Properties of this record
        ///   - fields: Fields of this record
        ///   - signals: List of signals for this record
        ///   - interfaces: Interfaces implemented by this record
        ///   - comment: Documentation text for the constant
        ///   - introspectable: Set to `true` if introspectable
        ///   - deprecated: Documentation on deprecation status if non-`nil`
        public init(name: String, type: TypeReference, cprefix: String, typegetter: String, methods: [Method] = [], functions: [Function] = [], constructors: [Method] = [], properties: [Property] = [], fields: [Field] = [], signals: [Signal] = [], interfaces: [String] = [], comment: String = "", introspectable: Bool = false, deprecated: String? = nil) {
            self.cprefix = cprefix
            self.typegetter = typegetter
            self.methods = methods
            self.functions = functions
            self.constructors = constructors
            self.properties = properties
            self.fields = fields
            self.signals = signals
            self.implements = interfaces
            super.init(name: name, type: type, comment: comment, introspectable: introspectable, deprecated: deprecated)
        }

        /// Initialiser to construct a record type from XML
        /// - Parameters:
        ///   - node: `XMLElement` to construct this constant from
        ///   - index: Index within the siblings of the `node`
        public init(node: XMLElement, at index: Int) {
            cprefix = node.attribute(named: "symbol-prefix") ?? ""
            typegetter = node.attribute(named: "get-type") ?? ""
            typeStruct = node.attribute(named: "type-struct")
            let children = node.children.lazy
            let funcs = children.filter { $0.name == "function" }
            functions = funcs.enumerated().map { Function(node: $0.1, at: $0.0) }
            let meths = children.filter { $0.name == "method" }
            methods = meths.enumerated().map { Method(node: $0.1, at: $0.0) }
            let cons = children.filter { $0.name == "constructor" }
            constructors = cons.enumerated().map { Method(node: $0.1, at: $0.0) }
            let props = children.filter { $0.name == "property" }
            properties = props.enumerated().map { Property(node: $0.1, at: $0.0) }
            let fattrs = children.filter { $0.name == "field" }
            fields = fattrs.enumerated().map { Field(node: $0.1, at: $0.0) }
            let sigs = children.filter { $0.name == "signal" }
            signals = sigs.enumerated().map { Signal(node: $0.1, at: $0.0) }
            let interfaces = children.filter { $0.name == "implements" }
            implements = interfaces.enumerated().compactMap { $0.1.attribute(named: "name") }
            records = node.children.lazy.filter { $0.name ==  "record" }.enumerated().map {
                Record(node: $0.element, at: $0.offset)
            }
            super.init(node: node, at: index)
        }

        /// Register this type as a record type
        @inlinable
        override public func registerKnownType() {
            let type = typeRef.type
            let clsType = classType
            let proType = protocolType
            let refType = structType
            let protocolRef = self.protocolRef
            let clsRef = classRef
            if type.parent == nil { type.parent = protocolRef }
            if !GIR.recordTypes.contains(type) {
                GIR.recordTypes.insert(type)
            }
            let ref = structRef
            if GIR.protocols[type] == nil     { GIR.protocols[type]     = protocolRef }
            if GIR.protocols[clsType] == nil  { GIR.protocols[clsType]  = clsRef }
            if GIR.protocols[refType] == nil  { GIR.protocols[refType]  = protocolRef }
            if GIR.recordRefs[type] == nil    { GIR.recordRefs[type]    = ref }
            if GIR.recordRefs[clsType] == nil { GIR.recordRefs[clsType] = ref }
            if GIR.recordRefs[refType] == nil { GIR.recordRefs[refType] = ref }
            if GIR.recordRefs[proType] == nil { GIR.recordRefs[proType] = ref }
            if GIR.refRecords[proType] == nil { GIR.refRecords[proType] = typeRef }
            if GIR.refRecords[clsType] == nil { GIR.refRecords[clsType] = typeRef }
            if GIR.refRecords[refType] == nil { GIR.refRecords[refType] = typeRef }
            if GIR.refRecords[type] == nil    { GIR.refRecords[type]    = typeRef }
            let prefixedType = type.prefixed
            guard prefixedType !== type else { return }
            let prefixedCls = clsType.prefixed
            let prefixedRef = refType.prefixed
            let prefixedPro = proType.prefixed
            if GIR.protocols[prefixedType] == nil  { GIR.protocols[prefixedType]  = protocolRef }
            if GIR.protocols[prefixedCls] == nil   { GIR.protocols[prefixedCls]   = clsRef }
            if GIR.protocols[prefixedRef] == nil   { GIR.protocols[prefixedRef]   = protocolRef }
            if GIR.recordRefs[prefixedType] == nil { GIR.recordRefs[prefixedType] = ref }
            if GIR.recordRefs[prefixedCls] == nil  { GIR.recordRefs[prefixedCls]  = ref }
            if GIR.recordRefs[prefixedRef] == nil  { GIR.recordRefs[prefixedRef]  = ref }
            if GIR.recordRefs[prefixedPro] == nil  { GIR.recordRefs[prefixedPro]  = ref }
            if GIR.refRecords[prefixedPro] == nil  { GIR.refRecords[prefixedPro]  = typeRef }
            if GIR.refRecords[prefixedCls] == nil  { GIR.refRecords[prefixedCls]  = typeRef }
            if GIR.refRecords[prefixedRef] == nil  { GIR.refRecords[prefixedRef]  = typeRef }
            if GIR.refRecords[prefixedType] == nil { GIR.refRecords[prefixedType] = typeRef }
        }

        /// Name of the Protocol for this record
        @inlinable
        public var protocolName: String { typeRef.type.swiftName.protocolName }
        /// Name of the `Ref` struct for this record
        @inlinable
        public var structName: String { typeRef.type.swiftName + "Ref" }

        /// Type of the Class for this record
        @inlinable public var classType: GIRRecordType {
            let n = typeRef.type.swiftName.swift
            return GIRRecordType(name: n, typeName: n, ctype: typeRef.type.ctype)
        }

        /// Type of the Protocol for this record
        @inlinable public var protocolType: GIRType { GIRType(name: protocolName, typeName: protocolName, ctype: "") }

        /// Protocol reference for this record
        @inlinable public var protocolRef: TypeReference { TypeReference(type: protocolType) }

        /// Type of the `Ref` struct for this record
        @inlinable
        public var structType: GIRRecordType { GIRRecordType(name: structName, typeName: structName, ctype: "", superType: protocolRef) }

        /// Struct reference for this record
        @inlinable public var structRef: TypeReference { TypeReference(type: structType) }

        /// Class reference for this record
        @inlinable public var classRef: TypeReference { TypeReference(type: classType) }

        /// return the first method where the passed predicate closure returns `true`
        public func methodMatching(_ predictate: (Method) -> Bool) -> Method? {
            return allMethods.lazy.filter(predictate).first
        }

        /// return the first inherited method where the passed predicate closure returns `true`
        public func inheritedMethodMatching(_ predictate: (Method) -> Bool) -> Method? {
            return inheritedMethods.lazy.filter(predictate).first
        }

        /// return the first of my own or inherited methods where the passed predicate closure returns `true`
        public func anyMethodMatching(_ predictate: (Method) -> Bool) -> Method? {
            if let match = methodMatching(predictate) { return match }
            return inheritedMethodMatching(predictate)
        }

        /// return the `retain` (ref) method for the given record, if any
        public var ref: Method? { return anyMethodMatching { $0.isRef && $0.args.first!.isInstanceOfHierarchy(self) } }

        /// return the `release` (unref) method for the given record, if any
        public var unref: Method? { return anyMethodMatching { $0.isUnref && $0.args.first!.isInstanceOfHierarchy(self) } }

        /// return whether the record or one of its parents has a given property
        public func has(property name: String) -> Bool {
            guard properties.first(where: { $0.name == name }) == nil else { return true }
            guard let parent = parentType else { return false }
            return parent.has(property: name)
        }

        /// return only the properties that are not derived
        public var nonDerivedProperties: [Property] {
            guard let parent = parentType else { return properties }
            return properties.filter { !parent.has(property: $0.name) }
        }

        /// return all properties, including the ones derived from ancestors
        public var allProperties: [Property] {
            guard let parent = parentType else { return properties }
            let all = Set(properties).union(Set(parent.allProperties))
            return all.sorted()
        }

        /// return all signals, including the ones derived from ancestors
        public var allSignals: [Signal] {
            guard let parent = parentType else { return signals }
            let all = Set(signals).union(Set(parent.allSignals))
            return all.sorted()
        }
    }
    
}
