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

import libxml2

///
/// A wrapper around libxml2 xmlAttr
///
public struct XMLAttribute {
    let attr: xmlAttrPtr
}

extension XMLAttribute {
    /// name of the XML attribute
    public var name: String {
        guard attr != nil else { return "(NULL)" }
        guard let description = String.fromCString(UnsafePointer(attr.memory.name)) else { return "" }
        return description
    }

    /// children of the XML element
    public var children: AnySequence<XMLElement> {
        guard attr.memory.children != nil else { return emptySequence() }
        return AnySequence { XMLElement(node: self.attr.memory.children).generate() }
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
        guard attr != nil else { return "(NULL)" }
        return "\(description): \(attr.memory.type)"
    }
}

//
// MARK: - Enumerating XML Elements
//
extension XMLAttribute: SequenceType {
    public func generate() -> XMLAttribute.Generator {
        return Generator(root: self)
    }
}


extension XMLAttribute {
    public class Generator: GeneratorType {
        var current: XMLAttribute

        /// create a generator from a root element
        init(root: XMLAttribute) {
            current = root
        }

        /// return the next element following a depth-first pre-order traversal
        public func next() -> XMLAttribute? {
            guard current.attr != nil else { return nil }
            let c = current
            current = XMLAttribute(attr: current.attr.memory.next) // sibling
            return c
        }
    }
}
