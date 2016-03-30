//
//  XMLNameSpace.swift
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
/// XML Name space representation
///
public struct XMLNameSpace {
    let ns: xmlNsPtr
}

extension XMLNameSpace {
    /// prefix of the XML namespace
    public var prefix: String? {
        return String.fromCString(UnsafePointer(ns.memory.prefix))
    }

    /// href URI of the XML namespace
    public var href: String? {
        return String.fromCString(UnsafePointer(ns.memory.href))
    }
}


//
// MARK: - Enumerating XML namespaces
//
extension XMLNameSpace: SequenceType {
    public func generate() -> XMLNameSpace.Generator {
        return Generator(root: self)
    }
}


extension XMLNameSpace {
    public class Generator: GeneratorType {
        var current: XMLNameSpace

        /// create a generator from a root element
        init(root: XMLNameSpace) {
            current = root
        }

        /// return the next element following a depth-first pre-order traversal
        public func next() -> XMLNameSpace? {
            guard current.ns != nil else { return nil }
            let c = current
            current = XMLNameSpace(ns: current.ns.memory.next)  // sibling
            return c
        }
    }
}
