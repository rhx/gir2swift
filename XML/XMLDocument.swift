//
//  XMLDocument.swift
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
/// A wrapper around libxml2 xmlDoc
///
public class XMLDocument {
    let xml: xmlDocPtr
    let ctx: xmlParserCtxtPtr = nil

    /// private constructor from a libxml document
    init(xmlDocument: xmlDocPtr) {
        precondition(xmlDocument != nil)
        xml = xmlDocument
        xmlInitParser()
    }

    /// failable initialiser from memory with a given parser function
    public convenience init?(buffer: UnsafeBufferPointer<CChar>, options: Int32 = Int32(XML_PARSE_NOWARNING.rawValue | XML_PARSE_NOERROR.rawValue | XML_PARSE_RECOVER.rawValue), parser: (UnsafePointer<CChar>, Int32, UnsafePointer<CChar>, UnsafePointer<CChar>, Int32) -> xmlDocPtr = xmlReadMemory) {
        let xml = parser(buffer.baseAddress, Int32(buffer.count), "", nil, options)
        guard xml != nil else { return nil }
        self.init(xmlDocument: xml)
    }

    /// initialise from a file
    public convenience init?(fromFile fileName: UnsafePointer<CChar>, options: Int32 = Int32(XML_PARSE_NOWARNING.rawValue | XML_PARSE_NOERROR.rawValue | XML_PARSE_RECOVER.rawValue)) {
        let xml = xmlParseFile(fileName)
        guard xml != nil else { return nil }
        self.init(xmlDocument: xml)
    }

    /// clean up
    deinit {
        xmlFreeDoc(xml)
    }

    /// get the root element
    public var rootElement: XMLElement {
        return XMLElement(node: xmlDocGetRootElement(xml))
    }

    /// get the XML tree for enumeration
    public var xmlTree: XMLTree {
        return XMLTree(xml: self)
    }

    /// get an attribute value
    public func valueFor(attribute: XMLAttribute) -> String? {
        guard attribute.attr != nil && attribute.attr.memory.children != nil else { return nil }
        let s = xmlNodeListGetString(xml, attribute.attr.memory.children, 1)
        let value = String.fromCString(UnsafePointer(s)) ?? ""
        xmlFree(s)
        return value
    }

    /// get the value for a named attribute
    public func valueFor(attribute name: String, inElement e: XMLElement) -> String? {
        guard let attr = (e.attributes.filter { $0.name == name }.first) else { return nil }
        return valueFor(attr)
    }
}


//
// MARK: - Enumerating XML
//
extension XMLDocument: SequenceType {
    public typealias Generator = XMLElement.Generator
    public func generate() -> Generator {
        return Generator(root: rootElement)
    }
}


///
/// Tree enumeration
///
public struct XMLTree: SequenceType {
    let document: XMLDocument

    public init(xml: XMLDocument) {
        document = xml
    }

    public class Generator: GeneratorType {
        let parent: XMLElement?
        var element: XMLElement
        var child: Generator?

        /// create a generator from a root element
        init(root: XMLElement, parent: XMLElement? = nil) {
            self.parent = parent
            element = root
        }

        /// return the next element following a depth-first pre-order traversal
        public func next() -> (node: XMLElement, parent: XMLElement?)? {
            if let c = child {
                if let element = c.next() { return element }         // children
                element = XMLElement(node: element.node.memory.next) // sibling
            }
            guard element.node != nil else { return nil }
            child = Generator(root: XMLElement(node: element.node.memory.children), parent: element)
            return (element, parent)
        }
    }

    public func generate() -> Generator {
        return Generator(root: document.rootElement)
    }
}