//
//  gir.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 25/03/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//

public class GIR {
    public let xml: XMLDocument
    public var namespace = ""
    public var identifierPrefixes = Array<String>()
    public var symbolPrefixes = Array<String>()

    /// designated constructor
    public init(xmlDocument: XMLDocument) {
        xml = xmlDocument
        if let ns = xml.findFirstWhere({ $0.name == "namespace" }) {
            namespace = ns.name
            identifierPrefixes = ns.sortedSubAttributesFor("identifier-prefixes")
            symbolPrefixes     = ns.sortedSubAttributesFor("symbol-prefixes")
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
    public func dumpSwift() -> String {
        var context = ConversionContext([:])
        context = ConversionContext(["repository": {
            let s = indent($0.level, "// \($0.node.name) @ \($0.level)+\(context.level)")
            context = context.push($0, ["namespace": {
                let s = indent($0.level, "// \($0.node.name) @ \($0.level)+\(context.level)")
                context = context.push($0, ["alias": {
                    context = context.push($0, ["type": {
                        let s: String
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
                    if let name = $0.node.attribute("name") where !name.isEmtpy {
                        s = "func \(name)("
                    } else { s = "// empty function " }
                    context = context.push($0, ["type": {
                        if let type  = $0.node.attribute("name"),
                            let alias = context.parentNode.node.attribute("name") where !alias.isEmpty && !type.isEmpty {
                            context.outputs = ["public typealias \(alias) = \(type)"]
                        } else {
                            context.output = "// error alias \($0.node.attribute("name")) = \(context.parentNode.node.attribute("name"))"
                        }
                        return ""
                        }])
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
}

