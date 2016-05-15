//
//  XMLPath.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 25/03/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import CLibXML2

///
/// A wrapper around libxml2 xmlXPathTypePtr
///
public struct XMLPath {
    let xpath: xmlXPathObjectPtr
}

///
/// Extension to make XMLPath behave like an array
///
extension XMLPath: Sequence {
    public typealias Index = Int
    public typealias Iterator = AnyIterator<XMLElement>
//    public typealias SubSequence = Array<XMLElement>

    var nodeSet: xmlNodeSetPtr? { return xpath.pointee.nodesetval }
    public var count: Int { return nodeSet != nil ? Int(nodeSet!.pointee.nodeNr) : 0 }
    public var startIndex: Index { return 0 }
    public var endIndex: Index { return count }
    public var first: XMLElement? {
        guard count > 0 else { return nil }
        return self.at(index: startIndex)
    }
    public var last: XMLElement? {
        guard count > 0 else { return nil }
        return self.at(index: endIndex)
    }

    public func index(after i: Index) -> Index { return i+1 }

    public func formIndex(after i: inout Index) { i += 1 }

    public func at(index i: Index) -> XMLElement {
        precondition(i >= startIndex)
        precondition(i < endIndex)
        return XMLElement(node: nodeSet!.pointee.nodeTab![i]!)
    }

    public subscript(position i: Index) -> XMLElement {
        return at(index: i)
    }

//    public subscript(bounds: Range<Index>) -> Array<XMLElement> {
//        return []
//    }

    /// Returns an iterator over the elements of the XMLPath.
    public func makeIterator() -> Iterator {
        var i = 0
        return AnyIterator {
            let j = i
            guard j < self.count else { return nil }
            i += 1
            return self.at(index: j)
        }
    }
}

extension XMLDocument {
    /// compile a given XPath for queries
    public func xpath(_ p: String, namespaces ns: AnySequence<XMLNameSpace> = emptySequence(), defaultPrefix: String = "ns") -> XMLPath? {
        guard let context = xmlXPathNewContext(xml) else { return nil }
        defer { xmlXPathFreeContext(context) }
        ns.forEach { xmlXPathRegisterNs(context, $0.prefix ?? defaultPrefix, $0.href ?? "") }
        return xpath(p, context: context)
    }

    /// compile a given XPath for queries
    public func xpath(_ p: String, namespaces ns: [(prefix: String, href: String)]) -> XMLPath? {
        guard let context = xmlXPathNewContext(xml) else { return nil }
        defer { xmlXPathFreeContext(context) }
        ns.forEach { xmlXPathRegisterNs(context, $0.prefix, $0.href) }
        return xpath(p, context: context)
    }

    /// compile an xpath for queries with a given context
    public func xpath(_ p: String, context: xmlXPathContextPtr) -> XMLPath? {
        guard let xmlXPath = xmlXPathEvalExpression(p, context) else { return nil }
        return XMLPath(xpath: xmlXPath)
    }
}

