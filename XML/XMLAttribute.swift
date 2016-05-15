//
//  XMLAttribute.swift
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
/// A wrapper around libxml2 xmlAttr
///
public struct XMLAttribute {
    let attr: xmlAttrPtr
}

extension XMLAttribute {
    /// name of the XML attribute
    public var name: String {
        guard let name = attr.pointee.name else { return "" }
        let description = String(cString: UnsafePointer(name))
        return description
    }

    /// children of the XML attribute
    public var children: AnySequence<XMLElement> {
        guard attr.pointee.children != nil else { return emptySequence() }
        return AnySequence { XMLElement(node: self.attr.pointee.children).makeIterator() }
    }
}


//
// MARK: - Conversion to String
//
extension XMLAttribute: CustomStringConvertible {
    public var description: String { return name }
}

extension XMLAttribute: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "\(description): \(attr.pointee.type)"
    }
}

//
// MARK: - Enumerating XML Attributes
//
extension XMLAttribute: Sequence {
    public func makeIterator() -> XMLAttribute.Iterator {
        return Iterator(root: self)
    }
}


extension XMLAttribute {
    public class Iterator: IteratorProtocol {
        var current: XMLAttribute

        /// create a generator from a root element
        init(root: XMLAttribute) {
            current = root
        }

        /// return the next element following a depth-first pre-order traversal
        public func next() -> XMLAttribute? {
            let c = current
            current = XMLAttribute(attr: c.attr.pointee.next)   // sibling
            return c
        }
    }
}
