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
        guard node != nil else { return "" }
        guard let description = String.fromCString(UnsafePointer(node.memory.name)) else { return "" }
        return description
    }

    /// content of the XML element
    public var content: String {
        let content = xmlNodeGetContent(node)
        guard content != nil else { return "" }
        let txt = String.fromCString(UnsafePointer(content)) ?? ""
        xmlFree(content)
        return txt
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

    /// return the value of a given attribute in a given name space
    public func attribute(name: String, namespace: String) -> String? {
        let value = xmlGetNsProp(node, name, namespace)
        return String.fromCString(UnsafePointer(value))
    }

    /// return the boolean value of a given attribute
    public func bool(name: String) -> Bool {
        if let str = attribute(name),
           let val = Int(str) where val != 0 {
            return true
        } else {
            return false
        }
    }

    /// return the boolean value of a given attribute in a given name space
    public func bool(name: String, namespace: String) -> Bool {
        if let str = attribute(name, namespace:  namespace),
           let val = Int(str) where val != 0 {
            return true
        } else {
            return false
        }
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


//
// MARK: - Namespaces
//
extension XMLElement {
    /// name spaces of the XML element
    public var namespaces: AnySequence<XMLNameSpace> {
        guard node.memory.nsDef != nil else { return emptySequence() }
        return AnySequence { XMLNameSpace(ns: self.node.memory.nsDef).generate() }
    }
}
