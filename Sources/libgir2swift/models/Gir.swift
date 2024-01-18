//
//  gir.swift
//  gir2swift
//
//  Created by Rene Hexel on 25/03/2016.
//  Copyright © 2016, 2017, 2018, 2019, 2020, 2022, 2024 Rene Hexel. All rights reserved.
//
import SwiftLibXML

/// Designated containers for types that can have associated methods
private let methodContainers: Set<String> = [ "record", "class", "interface", "enumeration", "bitfield" ]

/// Check whether a given XML element represents a free function
/// (as opposed to a method inside a type)
/// - Parameter function: XML element to be checked
func isFreeFunction(_ function: XMLElement) -> Bool {
    let isContained = methodContainers.contains(function.parent.name)
    return !isContained
}

/// Representation of a GIR file
public final class GIR {
    /// The parsed XML document represented by the receiver
    public let xml: XMLDocument
    /// Preample boilerplate to output before any generated code
    public var preamble = ""
    /// Namespace prefix defined by the receiver
    public var prefix = "" {
        didSet {
            GIR.prefix = prefix
            GIR.dottedPrefix = prefix + "."
        }
    }
    /// Current namespace prefix
    public static var prefix = ""
    /// Current namespace prefix  with a trailing "."
    public static var dottedPrefix = ""
    /// Collection of identifier prefixes
    public var identifierPrefixes = Array<String>()
    /// Collection of symbol prefixes
    public var symbolPrefixes = Array<String>()
    /// Type-erased sequence of namespaces
    public var namespaces: AnySequence<XMLNameSpace> = emptySequence()
    /// Aliases defined by this GIR file
    public var aliases: [Alias] = []
    /// Constants defined by this GIR file
    public var constants: [Constant] = []
    /// Enums defined by this GIR file
    public var enumerations: [Enumeration] = []
    /// Bitfields defined by this GIR file
    public var bitfields: [Bitfield] = []
    /// Interfaces defined by this GIR file
    public var interfaces: [Interface] = []
    /// Records defined by this GIR file
    public var records: [Record] = []
    /// Unions defined by this GIR file
    public var unions: [Union] = []
    /// Classes defined by this GIR file
    public var classes: [Class] = []
    /// Free functions defined by this GIR file
    public var functions: [Function] = []
    /// Callbacs defined by this GIR file
    public var callbacks: [Callback] = []

    /// DocC hosting base path relative to `/`.
    public static var docCHostingBasePath = ""

    /// Names of excluded identifiers.
    public static var excludeList: Set<String> = []

    /// names of constants to be taken verbatim
    public static var verbatimConstants: Set<String> = []

    /// names of override initialisers
    public static var overrides: Set<String> = []

    /// known types indexed by C identifier.
    public static var knownCIdentifiers: [ String : Datatype ] = [:]
    /// context of known types
    public static var knownDataTypes:   [ String : Datatype ] = [:]
    /// context of known records
    public static var knownRecords: [ String : Record ] = [:]
    /// context of known records
    public static var knownBitfields: [ String : Bitfield ] = [:]
    /// context of known functions
    public static var KnownFunctions: [ String : Function ] = [:]
    /// suffixes for `@escaping` callback heuristics
    public static var callbackSuffixes = [String]()
    /// types to turn into force-unwrapped optionals
    public static var forceUnwrapped: Set<String> = ["gpointer", "gconstpointer"]

    /// Dotted namespace replacements
    public static var namespaceReplacements: [ Substring : Substring ] = [
        "GObject." : "GLibObject.", "Gio." : "GIO.", "GdkPixbuf." : "GdkPixBuf.", "cairo." : "Cairo."
    ]

    /// Names of typed collections.
    public static var typedCollections: Set<String> = [
        "GLib.List", "GLib.SList", "GLib.PtrArray"
    ]

    /// Name of the GLib pointer wrapper that every type conforms to.
    public static var glibPointerWrapper = "GLib.PointerWrapper"

    /// designated constructor
    public init(xmlDocument: XMLDocument, quiet: Bool = false) {
        xml = xmlDocument
        if let rp = xml.first(where: { $0.name == "repository" }) {
            namespaces = rp.namespaces
        }
        //
        // set up name space prefix
        //
        if let ns = xml.xpath("//gir:namespace", namespaces: namespaces, defaultPrefix: "gir")?.makeIterator().next() {
            if let name = ns.attribute(named: "name") {
                prefix = name
                GIR.prefix = name
                GIR.dottedPrefix = name + "."
            }
            identifierPrefixes = ns.sortedSubAttributesFor(attr: "identifier-prefixes")
            symbolPrefixes     = ns.sortedSubAttributesFor(attr: "symbol-prefixes")
        }
        withUnsafeMutablePointer(to: &GIR.knownDataTypes) { (knownTypes: UnsafeMutablePointer<[ String : Datatype ]>) -> Void in
          withUnsafeMutablePointer(to: &GIR.knownRecords) { (knownRecords: UnsafeMutablePointer<[ String : Record]>) -> Void in
            withUnsafeMutablePointer(to: &GIR.knownBitfields) { (knownBitfields: UnsafeMutablePointer<[ String : Bitfield]>) -> Void in
            let prefixed: (String) -> String = { $0.prefixed(with: self.prefix) }

            func setKnown<T>(_ d: UnsafeMutablePointer<[ String : T]>) -> (String, T) -> Bool {
                return { (name: String, type: T) -> Bool in
                    guard d.pointee[name] == nil || d.pointee[prefixed(name)] == nil else { return false }
                    let prefixedName = prefixed(name)
                    d.pointee[name] = type
                    d.pointee[prefixedName] = type
                    if GIR.namespaceReplacements[prefixedName.dottedPrefix] != nil {
                        let alternativelyPrefixed = prefixedName.withNormalisedPrefix
                        d.pointee[alternativelyPrefixed] = type
                    }
                    return true
                }
            }
            func setKnownCIdentifier(ofType type: Datatype) {
                let maybeCType = type as? CType
                let isCTypeNameEmpty = maybeCType?.cname.isEmpty ?? true
                if !isCTypeNameEmpty || !type.typeRef.type.ctype.isEmpty {
                    let cName = isCTypeNameEmpty ? type.typeRef.type.ctype : maybeCType!.cname
                    if GIR.knownCIdentifiers[cName] == nil {
                        GIR.knownCIdentifiers[cName] = type
                    }
                }
            }
            let setKnownTypeFunc = setKnown(knownTypes)
            let setKnownType = {
                setKnownCIdentifier(ofType: $1)
                return setKnownTypeFunc($0, $1)
            }
            let setKnownRecord = setKnown(knownRecords)
            let setKnownBitfield = setKnown(knownBitfields)
            //
            // get all type alias records
            //
            if let entries = xml.xpath("/*/*/gir:alias", namespaces: namespaces, defaultPrefix: "gir") {
                aliases = entries.enumerated().map { Alias(node: $0.1, at: $0.0) }.filter {
                    let name = $0.name
                    guard setKnownType(name, $0) else {
                        if !quiet { print("Warning: duplicate type '\(name)' for alias ignored!", to: &Streams.stdErr) }
                        return false
                    }
                    return true
                }
            }
            /// function for recording known types
            func notKnownType<T: Datatype>(_ e: T) -> Bool {
                return setKnownType(e.name, e)
            }
            /// function for recording known constants
            func notKnownConstant(_ constant: Constant) -> Bool {
                let idiomaticName = constant.swiftCamelCASEName
                let idiomaticNameWorks = setKnownType(idiomaticName, constant) && GIR.KnownFunctions[idiomaticName] == nil
                return notKnownType(constant) || idiomaticNameWorks
            }
            let notKnownRecord: (Record) -> Bool = {
                $0.constructors.forEach { setKnownCIdentifier(ofType: $0) }
                $0.methods.forEach { setKnownCIdentifier(ofType: $0) }
                $0.functions.forEach { setKnownCIdentifier(ofType: $0) }
                guard notKnownType($0) else { return false }
                return setKnownRecord($0.name, $0)
            }
            let notKnownBitfield: (Bitfield) -> Bool     = {
                $0.members.forEach { setKnownCIdentifier(ofType: $0) }
                guard notKnownType($0) else { return false }
                return setKnownBitfield($0.name, $0)
            }
            let notKnownFunction: (Function) -> Bool = {
                setKnownCIdentifier(ofType: $0)
                let name = $0.name
                guard GIR.KnownFunctions[name] == nil else { return false }
                GIR.KnownFunctions[name] = $0
                let idiomaticSwiftName = name.snakeCase2camelCase
                if GIR.KnownFunctions[idiomaticSwiftName] == nil {
                    GIR.KnownFunctions[idiomaticSwiftName] = $0
                }
                return true
            }
            /// Record known enums and their values
            func notKnownEnum(_ e: Enumeration) -> Bool {
                e.members.forEach { setKnownCIdentifier(ofType: $0) }
                return notKnownType(e)
            }

            //
            // get all constants, enumerations, records, classes, and functions
            //
            constants    = enumerate(xml, path: "/*/*/gir:constant",    inNS: namespaces, quiet: quiet, construct: { Constant(node: $0, at: $1) },    check: notKnownConstant)
            enumerations = enumerate(xml, path: "/*/*/gir:enumeration", inNS: namespaces, quiet: quiet, construct: { Enumeration(node: $0, at: $1) }, check: notKnownEnum)
            bitfields    = enumerate(xml, path: "/*/*/gir:bitfield",    inNS: namespaces, quiet: quiet, construct: { Bitfield(node: $0, at: $1) },    check: notKnownBitfield)
            interfaces   = enumerate(xml, path: "/*/*/gir:interface",   inNS: namespaces, quiet: quiet, construct: { Interface(node: $0, at: $1) }, check: notKnownRecord)
            records      = enumerate(xml, path: "/*/*/gir:record",      inNS: namespaces, quiet: quiet, construct: { Record(node: $0, at: $1) },    check: notKnownRecord)
            classes      = enumerate(xml, path: "/*/*/gir:class",       inNS: namespaces, quiet: quiet, construct: { Class(node: $0, at: $1) },     check: notKnownRecord)
            unions       = enumerate(xml, path: "/*/*/gir:union",       inNS: namespaces, quiet: quiet, construct: { Union(node: $0, at: $1) },     check: notKnownRecord)
            callbacks    = enumerate(xml, path: "/*/*/gir:callback",    inNS: namespaces, quiet: quiet, construct: { Callback(node: $0, at: $1) },    check: notKnownType)
            functions    = enumerate(xml, path: "//gir:function",       inNS: namespaces, quiet: quiet, construct: {
                isFreeFunction($0) ? Function(node: $0, at: $1) : nil
                }, check: notKnownFunction)
          }
        }
      }
      buildClassHierarchy()
      buildConformanceGraph()
    }

    /// convenience constructor to read a gir file
    public convenience init?(fromFile name: String) {
        guard let xml = XMLDocument(fromFile: name) else { return nil }
        self.init(xmlDocument: xml)
    }

    /// convenience constructor to read from memory
    public convenience init?(buffer content: UnsafeBufferPointer<CChar>, quiet q: Bool = false) {
        guard let xml = XMLDocument(buffer: content) else { return nil }
        self.init(xmlDocument: xml, quiet: q)
    }

    /// Traverse all the classes and record their relationship in the type hierarchy
    @inlinable
    public func buildClassHierarchy() {
        for cl in classes {
            recordImplementedInterfaces(for: cl)
            guard cl.typeRef.type.parent == nil else { continue }
            if let parent = cl.parentType {
                cl.typeRef.type.parent = parent.typeRef
            }
        }
    }

    /// Traverse all the records and record all the interfaces implemented
    @inlinable
    public func buildConformanceGraph() {
        records.forEach { recordImplementedInterfaces(for: $0) }
    }

    /// Traverse all the records and record all the interfaces implemented
    @discardableResult @inlinable
    public func recordImplementedInterfaces(for record: Record) -> Set<TypeReference> {
        let t = record.typeRef.type
        if let interfaces = GIR.implements[t] { return interfaces }
        let implements = record.implements.compactMap { GIR.knownDataTypes[$0] }
        var implementations = Set(implements.map(\.typeRef))
        let implementedRecords = implements.compactMap { $0 as? Record }
        implementations.formUnion(implementedRecords.flatMap { recordImplementedInterfaces(for: $0) })
        if let parent = record.parentType {
            implementations.formUnion(recordImplementedInterfaces(for: parent))
        }
        GIR.implements[t] = implementations
        if let ref = GIR.recordRefs[t] { GIR.implements[ref.type] = implementations }
        if let pro = GIR.protocols[t]  { GIR.implements[pro.type] = implementations }
        return implementations
    }
}

extension GIR {
    ///
    /// return the documentation for the given child nodes
    ///
    public class func docs(children: LazySequence<AnySequence<XMLElement>>) -> String {
        return documentation(name: "doc", children: children)
    }

    ///
    /// return the documentation for the given child nodes
    ///
    public class func deprecatedDocumentation(children: LazySequence<AnySequence<XMLElement>>) -> String? {
        let doc = documentation(name: "doc-deprecated", children: children)
        guard !doc.isEmpty else { return nil }
        return doc
    }

    ///
    /// return the documentation for the given child nodes
    ///
    public class func documentation(name: String, children: LazySequence<AnySequence<XMLElement>>) -> String {
        let docs = children.filter { $0.name == name }
        let comments = docs.map { $0.content}
        return comments.joined(separator: "\n")
    }

    ///
    /// return the method/function arguments for the given child nodes
    ///
    public class func args(children: LazySequence<AnySequence<XMLElement>>) -> [Argument] {
        let parameters = children.filter { $0.name.hasSuffix("parameter") }
        let args = parameters.enumerated().map { Argument(node: $1, at: $0) }
        return args
    }

    ///
    /// return the type information of an argument or return type node
    ///
    class func typeOf(node: XMLElement) -> TypeReference {
        let t = node.type
        if !t.isVoid { return t }
        for child in node.children {
            let t = child.type
            if !t.isVoid { return t }
        }
        return .void
    }

    ///
    /// dump Swift code
    ///
    public func dumpSwift() -> String {
        var context = ConversionContext([:])
        context = ConversionContext(["repository": {
            let s = indent(level: $0.level, "// \($0.node.name) @ \($0.level)+\(context.level)")
            context = context.push(node: $0, ["namespace": {
                let s = indent(level: $0.level, "// \($0.node.name) @ \($0.level)+\(context.level)")
                context = context.push(node: $0, ["alias": {
                    context = context.push(node: $0, ["type": {
                        if let type  = $0.node.attribute(named: "name"),
                           let alias = context.parentNode.node.attribute(named: "name"),
                              !alias.isEmpty && !type.isEmpty {
                            context.outputs = ["public typealias \(alias) = \(type)"]
                        } else {
                            context.outputs = ["// error alias \(String(describing: $0.node.attribute(named: "name"))) = \(String(describing: context.parentNode.node.attribute(named: "name")))"]
                        }
                        return ""
                        }])
                    return s
                }, "function": {
                    let s: String
                    if let name = $0.node.attribute(named: "name"), !name.isEmpty {
                        s = "func \(name)("
                    } else { s = "// empty function " }
                    context = context.push(node: $0, ["type": {
                        if let type  = $0.node.attribute(named: "name"),
                            let alias = context.parentNode.node.attribute(named: "name"),
                               !alias.isEmpty && !type.isEmpty {
                            context.outputs = ["public typealias \(alias) = \(type)"]
                        } else {
                            context.outputs = ["// error alias \(String(describing: $0.node.attribute(named: "name"))) = \(String(describing: context.parentNode.node.attribute(named: "name")))"]
                        }
                        return ""
                        }])
                    return s
                }])
                return s
            }])
            return s
        }])
        return (xml.tree.map { (tn: XMLTree.Node) -> String in
            if let f = context.conversion[tn.node.name] { return f(tn) }
            while context.level > tn.level {
                if let parent = context.parent { context = parent }
                else { assert(context.level == 0) }
            }
            return indent(level: tn.level, "// unhandled: \(tn.node.name) @ \(tn.level)+\(context.level)")
            }).reduce("") { (output: String, element: String) -> String in
                output + "\(element)\n"
        }
    }
}
