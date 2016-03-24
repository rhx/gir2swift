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

    /// clean up
    deinit {
        xmlFreeDoc(xml)
    }
}


//
// MARK: - Enumerating XML
//
extension XMLDocument: SequenceType {
    public typealias Generator = XMLElement.Generator
    public func generate() -> Generator {
        return Generator(root: XMLElement(node: xmlDocGetRootElement(xml)))
    }
}
