//
//  c2swift.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 29/04/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
import Foundation

private let wsnl = NSCharacterSet.whitespaceAndNewlineCharacterSet()

extension String {
    /// return whether the type represented by the receiver is a constant
    public var isCConst: Bool {
        let ns = stringByTrimmingCharactersInSet(wsnl)
        return ns.hasPrefix("const ") || ns.containsString(" const")
    }

    /// return the C type without a trailing "const"
    public var typeWithoutTrailingConst: String {
        let ns = stringByTrimmingCharactersInSet(wsnl)
        let p: String
        if (ns.hasSuffix("const")) {
            let cs = ns.characters
            let s = cs.startIndex
            let e = s.advancedBy(cs.count - 4)
            p = String(ns.characters[s..<e])
        } else {
            p = ns
        }
        return p
    }

    /// return the C type without "const"
    public var typeWithoutConst: String {
        let ns = stringByReplacingOccurrencesOfString("const", withString: "")
        return ns.stringByTrimmingCharactersInSet(wsnl)
    }

    /// return whether the underlying C type is a pointer
    public var isCPointer: Bool {
        return typeWithoutTrailingConst.stringByTrimmingCharactersInSet(wsnl).hasSuffix("*")
    }

    /// return the underlying C type for a pointer, nil if not a pointer
    public var underlyingTypeForCPointer: String? {
        guard isCPointer else { return nil }
        let ns = typeWithoutTrailingConst
        let cs = ns.characters
        let s = ns.characters.startIndex
        let e = ns.characters.endIndex.predecessor()
        return String(cs[s..<e])
    }

    /// return the Swift type for a given C type
    public var swiftRepresentationOfCType: String {
        if let base = underlyingTypeForCPointer {
            let pointer = isCConst ? "UnsafePointer" : "UnsafeMutablePointer"
            let wrapped = pointer + "<\(base.swiftRepresentationOfCType)>"
            return wrapped
        }
        return typeWithoutConst
    }
}

/// convert the given C type to a Swift type
func toSwift(_ ctype: String) -> String {
    return ctype.swiftRepresentationOfCType
}
