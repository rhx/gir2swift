//
//  XMLElement.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 24/03/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import libxml2

///
/// A wrapper around libxml2 xmlElement
///
public struct XMLElement {
    let node: xmlNodePtr
}

extension XMLElement {
    /// name of the XML element
    public var name: String {
        guard node != nil else { return "(NULL)" }
        guard let description = String.fromCString(UnsafePointer(node.memory.name)) else { return "" }
        return description
    }

    /// attributes of the XML element
    public var attributes: AnySequence<XMLAttribute> {
        guard node.memory.properties != nil else { return emptySequence() }
        return AnySequence { XMLAttribute(attr: self.node.memory.properties).generate() }
    }

    /// children of the XML element
    public var children: AnySequence<XMLElement> {
        guard node.memory.children != nil else { return emptySequence() }
        return AnySequence { XMLElement(node: self.node.memory.children).generate() }
    }

    /// return the value of a given attribute
    public func attribute(name: String) -> String? {
        let value = xmlGetProp(node, name)
        return String.fromCString(UnsafePointer(value))
    }
}


//
// MARK: - Conversion to String
//
extension XMLElement: CustomStringConvertible {
    public var description: String { return name }
}

extension XMLElement: CustomDebugStringConvertible {
    public var debugDescription: String {
        guard node != nil else { return "(NULL)" }
        return "\(description): \(node.memory.type)"
    }
}

//
// MARK: - Enumerating XML Elements
//
extension XMLElement: SequenceType {
    public func generate() -> XMLElement.Generator {
        return Generator(root: self)
    }
}


extension XMLElement {
    public class Generator: GeneratorType {
        var element: XMLElement
        var child: Generator?

        /// create a generator from a root element
        init(root: XMLElement) {
            element = root
        }

        /// return the next element following a depth-first pre-order traversal
        public func next() -> XMLElement? {
            if let c = child {
                if let element = c.next() { return element }         // children
                element = XMLElement(node: element.node.memory.next) // sibling
            }
            guard element.node != nil else { return nil }
            child = XMLElement(node: element.node.memory.children).generate()
            return element
        }
    }
}
