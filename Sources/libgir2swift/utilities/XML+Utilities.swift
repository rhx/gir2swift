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

/// Enumerate a subtree of an XML document designated by an XPath expression
/// - Parameters:
///   - xml: the XML document to enumerate
///   - path: XPath representation of the subtry to enumerate
///   - namespaces: namespaces to consider
///   - quiet: suppress warnings if `true`
///   - construct: callback to construct a given type `T` represented by an XML element
///   - prefix: default Namespace prefix to register
///   - check: callback to check whether the current element should be included
func enumerate<T>(_ xml: XMLDocument, path: String, inNS namespaces: AnySequence<XMLNameSpace>, quiet: Bool, construct: (XMLElement, Int) -> T?, defaultPrefix prefix: String = "gir", check: (T) -> Bool = { _ in true }) -> [T] where T: GIR.Thing {
    if let entries = xml.xpath(path, namespaces: namespaces, defaultPrefix: prefix) {
        let things = entries.lazy.enumerated().map { construct($0.1, $0.0) }.filter {
            guard let node = $0 else { return false }
            guard check(node) else {
                if !quiet {
                    fputs("Warning: duplicate type '\(node.name)' for \(path) ignored!\n", stderr)
                }
                return false
            }

            return true
        }
        .map { $0! }

        return things
    }
    return []
}

extension XMLElement {
    ///
    /// return an attribute as a list of sub-attributeds split by a given character
    /// and ordered with the longest attribute name first
    ///
    public func sortedSubAttributesFor(attr: String, splitBy char: Character = ",", orderedBy: (String, String) -> Bool = { $0.count > $1.count || ($0.count == $1.count && $0 < $1)}) -> [String] {
        guard let attrs = (attribute(named: attr)?.split(separator: char))?.map({ String($0) }) else { return [] }
        return attrs.sorted(by: orderedBy)
    }

    ///
    /// return the documentation for a given node
    ///
    public func docs() -> String {
        return GIR.docs(children: children.lazy)
    }
}
