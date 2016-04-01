//
//  gir.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 25/03/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//

public class GIR {
    public let xml: XMLDocument
    public var prefix = ""
    public var identifierPrefixes = Array<String>()
    public var symbolPrefixes = Array<String>()
    public var namespaces: AnySequence<XMLNameSpace> = emptySequence()
    public var aliases: [Alias] = []
    public var records: [Record] = []

    /// designated constructor
    public init(xmlDocument: XMLDocument) {
        xml = xmlDocument
        if let rp = xml.findFirstWhere({ $0.name == "repository" }) {
            namespaces = rp.namespaces
            for n in namespaces {
                print("Got \(n.prefix) at \(n.href)")
            }
        }
        //
        // set up name space prefix
        //
        if let ns = xml.xpath("//gir:namespace", namespaces: namespaces, defaultPrefix: "gir")?.generate().next() {
            if let name = ns.attribute("name") {
                prefix = name
            }
            identifierPrefixes = ns.sortedSubAttributesFor("identifier-prefixes")
            symbolPrefixes     = ns.sortedSubAttributesFor("symbol-prefixes")
        }
        //
        // get all type alias records
        //
        if let entries = xml.xpath("//gir:alias", namespaces: namespaces, defaultPrefix: "gir") {
            aliases = entries.enumerate().map { Alias.fromNode($0.1, atIndex: $0.0) }
        }
        //
        // get all type records
        //
        if let recs = xml.xpath("//gir:record", namespaces: namespaces, defaultPrefix: "gir") {
            records = recs.enumerate().map { Record(node: $0.1, atIndex: $0.0) }
        }
    }

    /// convenience constructor to read a gir file
    public convenience init?(fromFile name: String) {
        guard let xml = XMLDocument(fromFile: name) else { return nil }
        self.init(xmlDocument: xml)
    }

    /// convenience constructor to read from memory
    public convenience init?(buffer content: UnsafeBufferPointer<CChar>) {
        guard let xml = XMLDocument(buffer: content) else { return nil }
        self.init(xmlDocument: xml)
    }

    /// a type alias entry
    public struct Alias {
        public let name: String         ///< type name without namespace/prefix
        public let type: String         ///< C typedef name
        public let ctype: String        ///< underlying C type
        public let comment: String      ///< documentation

        /// factory method to construct an alias from XML
        static func fromNode(node: XMLElement, atIndex i: Int) -> Alias {
            let name = node.attribute("name") ?? "Unknown\(i)"
            let type = node.attribute("type") ?? ""
            let children = node.children.lazy
            var types = children.filter { $0.name == "type" }.generate()
            let ctype: String
            if let typeEntry = types.next() {
                ctype = typeEntry.attribute("name") ?? (typeEntry.attribute("type") ?? "Void /* unknown type \(i) */")
            } else {
                ctype = "Void /* unknown type \(i) */"
            }
            let docs = GIR.docs(children)
            return Alias(name: name, type: !type.isEmpty ? type : ctype, ctype: ctype, comment: docs)
        }
    }

    /// a data type record to create a protocol/struct/class for
    public class Record {
        public let name: String         ///< type name without namespace/prefix
        public let type: String         ///< original type name
        public let ctype: String        ///< C language type name
        public let cprefix: String      ///< C language symbol prefix
        public let typegetter: String   ///< C type getter function
        public let methods: [Method]    ///< all associated methods
        public let comment: String      ///< documentation

        public init(name: String, type: String, ctype: String, cprefix: String, typegetter: String, methods: [Method], comment: String) {
            self.name = name
            self.type = type
            self.ctype = ctype
            self.cprefix = cprefix
            self.typegetter = typegetter
            self.methods = methods
            self.comment = comment
        }

        init(node: XMLElement, atIndex i: Int) {
            name = node.attribute("name") ?? "unknown\(i)"
            type = node.attribute("type-name") ?? ""
            ctype = node.attribute("type") ?? "void /* unknown \(i) */"
            cprefix = node.attribute("symbol-prefix") ?? ""
            typegetter = node.attribute("get-type") ?? ""
            let children = node.children.lazy
            comment = GIR.docs(children)
            let functions = children.filter { $0.name == "function" }
            methods = functions.enumerate().map { Method.fromNode($0.1, atIndex: $0.0) }
        }
    }

    /// a class data type record
    public class Class: Record {
        public let parent: String           ///< parent class name
        public let constructors: [Method]   ///< list of constructors

        override init(node: XMLElement, atIndex i: Int) {
            parent = ""
            constructors = []
            super.init(node: node, atIndex: i)
        }
    }

    /// data type representing a function/method
    public struct Method {
        public let name: String         ///< type name without namespace/prefix
        public let cname: String        ///< original C function name
        public let returns: Argument    ///< C language type name
        public let args: [Argument]     ///< all associated methods
        public let introspectable: Bool ///< is this method introspectable?
        public let comment: String      ///< documentation
        public let deprecated: String?  ///< alternative to use if deprecated

        static func fromNode(node: XMLElement, atIndex i: Int) -> Method {
            let name = node.attribute("name") ?? "unknownMethod\(i)"
            let cname = node.attribute("identifier") ?? ""
            let children = node.children.lazy
            let rv: Argument
            if let ret = children.findFirstWhere({ $0.name == "return-value"}) {
                rv = Argument.fromNode(ret, atIndex: -1)
            } else {
                rv = Argument(name: "", type: "Void", ctype: "void", comment: "")
            }
            let args = GIR.args(children)
            let docs = GIR.docs(children)
            let depr = GIR.deprecatedDocumentation(children)
            let introspect: Bool
            if let intr = node.attribute("introspectable"),
               let valu = Int(intr) where valu != 0 {
                introspect = true
            } else {
                introspect = false
            }
            return Method(name: name, cname: cname, returns: rv, args: args, introspectable: introspect, comment: docs, deprecated:  depr)
        }
    }

    /// data type representing a function/method argument or return type
    public struct Argument {
        public let name: String         ///< name without namespace/prefix
        public let type: String         ///< type name without namespace/prefix
        public let ctype: String        ///< C lanaguage type name
        public let comment: String      ///< documentation

        static func fromNode(node: XMLElement, atIndex i: Int) -> Argument {
            let name = node.attribute("name") ?? ""
            let (type, ctype) = GIR.types(node, at: i)
            let children = node.children.lazy
            let docs = GIR.docs(children)
            return Argument(name: name, type: type, ctype: ctype, comment: docs)
        }
    }
}

/// helper context class for tree traversal
class ConversionContext {
    let level: Int
    let parent: ConversionContext?
    let parentNode: XMLTree.Node!
    let conversion: [String : XMLTree.Node -> String]
    var outputs: [String] = []

    init(_ conversion: [String : XMLTree.Node -> String] = [:], level: Int = 0, parent: ConversionContext? = nil, parentNode: XMLTree.Node? = nil) {
        self.level = level
        self.parent = parent
        self.parentNode = parentNode
        self.conversion = conversion
    }

    /// push a context
    func push(node: XMLTree.Node, _ fs: [String : XMLTree.Node -> String]) -> ConversionContext {
        return ConversionContext(fs, level: node.level+1, parent: self, parentNode: node)
    }
}

private func indent(level: Int, _ s: String = "") -> String {
    return String(count: level * 4, repeatedValue: Character(" ")) + s
}

extension GIR {
    ///
    /// return the documentation for the given child nodes
    ///
    public class func docs(children: LazySequence<AnySequence<XMLElement>>) -> String {
        return documentation("doc", children: children)
    }

    ///
    /// return the documentation for the given child nodes
    ///
    public class func deprecatedDocumentation(children: LazySequence<AnySequence<XMLElement>>) -> String? {
        let doc = documentation("doc-deprecated", children: children)
        guard !doc.isEmpty else { return nil }
        return doc
    }

    ///
    /// return the documentation for the given child nodes
    ///
    public class func documentation(name: String, children: LazySequence<AnySequence<XMLElement>>) -> String {
        let docs = children.filter { $0.name == name }
        let comments = docs.map { $0.content}
        return comments.joinWithSeparator("\n")
    }

    ///
    /// return the method/function arguments for the given child nodes
    ///
    public class func args(children: LazySequence<AnySequence<XMLElement>>) -> [Argument] {
        let parameters = children.filter { $0.name == "parameter" }
        let args = parameters.enumerate().map { Argument.fromNode($1, atIndex: $0) }
        return args
    }

    ///
    /// return the array / type information of an argument or return type node
    ///
    class func types(node: XMLElement, at i: Int) -> (type: String, ctype: String) {
        for child in node.children {
            let type = child.attribute("name") ?? (child.attribute("type") ?? "Void /* unknown type \(i) */")
            let t: XMLElement
            if child.name == "type" { t = child }
            else if let at = child.children.filter({ $0.name == "type" }).first {
                t = at
            } else { continue }
            let ctype = t.attribute("type") ?? (t.attribute("name") ?? "void /* untyped argument \(i)")
            return (type: type, ctype: ctype)
        }
        return (type: "Void /* missing type \(i) */", ctype: "void /* missing C type \(i)")
    }

    ///
    /// dump Swift code
    ///
    public func dumpSwift() -> String {
        var context = ConversionContext([:])
        context = ConversionContext(["repository": {
            let s = indent($0.level, "// \($0.node.name) @ \($0.level)+\(context.level)")
            context = context.push($0, ["namespace": {
                let s = indent($0.level, "// \($0.node.name) @ \($0.level)+\(context.level)")
                context = context.push($0, ["alias": {
                    context = context.push($0, ["type": {
                        if let type  = $0.node.attribute("name"),
                           let alias = context.parentNode.node.attribute("name") where !alias.isEmpty && !type.isEmpty {
                            context.outputs = ["public typealias \(alias) = \(type)"]
                        } else {
                            context.outputs = ["// error alias \($0.node.attribute("name")) = \(context.parentNode.node.attribute("name"))"]
                        }
                        return ""
                        }])
                    return s
                }, "function": {
                    let s: String
                    if let name = $0.node.attribute("name") where !name.isEmpty {
                        s = "func \(name)("
                    } else { s = "// empty function " }
                    context = context.push($0, ["type": {
                        if let type  = $0.node.attribute("name"),
                            let alias = context.parentNode.node.attribute("name") where !alias.isEmpty && !type.isEmpty {
                            context.outputs = ["public typealias \(alias) = \(type)"]
                        } else {
                            context.outputs = ["// error alias \($0.node.attribute("name")) = \(context.parentNode.node.attribute("name"))"]
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
            return indent(tn.level, "// unhandled: \(tn.node.name) @ \(tn.level)+\(context.level)")
            }).reduce("") { (output: String, element: String) -> String in
                output + "\(element)\n"
        }
    }
}

extension XMLElement {
    ///
    /// return an attribute as a list of sub-attributeds split by a given character
    /// and ordered with the longest attribute name first
    ///
    public func sortedSubAttributesFor(attr: String, splitBy char: Character = ",", orderedBy: (String, String) -> Bool = { $0.characters.count > $1.characters.count || ($0.characters.count == $1.characters.count && $0 < $1)}) -> [String] {
        guard let attrs = ((attribute(attr)?.characters)?.split(char))?.map(String.init) else { return [] }
        return attrs.sort(orderedBy)
    }

    ///
    /// return the documentation for a given node
    ///
    public func docs() -> String {
        return GIR.docs(children.lazy)
    }
}

