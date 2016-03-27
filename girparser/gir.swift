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

private func toSwift(e: XMLElement) -> String { return e.toSwift() }

extension GIR {
    public func dumpSwift() -> String {
        return xml.map(toSwift).reduce("") { $0 + "\($1)\n" }
    }
}

private let conversion: [String : XMLElement -> String] = [:]

extension XMLElement {
    ///
    /// return an attribute as a list of sub-attributeds split by a given character
    /// and ordered with the longest attribute name first
    ///
    public func sortedSubAttributesFor(attr: String, splitBy char: Character = ",", orderedBy: (String, String) -> Bool = { $0.characters.count > $1.characters.count || ($0.characters.count == $1.characters.count && $0 < $1)}) -> [String] {
        guard let attrs = ((attribute(attr)?.characters)?.split(char))?.map(String.init) else { return [] }
        return attrs.sort(orderedBy)
    }

    /// convert a given element to the corresponding Swift code
    public func toSwift() -> String {
        if let f = conversion[name] { return f(self) }
        return "// \(name)\n"
    }
}

