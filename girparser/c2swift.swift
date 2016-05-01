//
//  c2swift.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 29/04/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
import Foundation

private let castables = [ "gint" : "Int", "guint" : "UInt", "glong" : "Int",
    "gint8"  : "Int8",  "guint8"  : "UInt8",  "gint16" : "Int16", "guint16" : "UInt16",
    "gint32" : "Int32", "guint32" : "UInt32", "gint64" : "Int64", "guint64" : "UInt64",
    "gulong" : "UInt",  "gsize"   : "Int",  "gboolean" : "Bool", "gpointer" : "COpaquePointer" ]
private let reversecast = castables.reduce(Dictionary<String,String>()) {
    var dict = $0
    dict[$1.1] = $1.0
    return dict
}
private let wsnl = NSCharacterSet.whitespaceAndNewlineCharacterSet()

private let trueS  = "true"
private let falseS = "false"
private let nilS   = "nil"
private let declarationKeywords: Set = ["associatedtype", "class", "deinit", "enum", "extension", "func", "import", "init", "inout", "internal", "let", "operator", "private", "protocol", "public", "static", "struct", "subscript", "typealias", "var"];
private let statementKeywords: Set = ["break", "case", "continue", "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch", "where", "while"]
private let expressionKeywords: Set = ["as", "catch", "dynamicType", "false", "is", "nil", "rethrows", "super", "self", "Self", "throw", "throws", "true", "try", "#column", "#file", "#function", "#line."]
private let specificKeywords: Set = ["associativity", "convenience", "dynamic", "didSet", "final", "get", "infix", "indirect", "lazy", "left", "mutating", "none", "nonmutating", "optional", "override", "postfix", "precedence", "prefix", "Protocol", "required", "right", "set", "Type", "unowned", "weak", "willSet"]

infix operator ∪ { associativity left precedence 140 }

func ∪<T>(left: Set<T>, right: Set<T>) -> Set<T> {
    return left.union(right)
}
let swiftKeywords = declarationKeywords ∪ statementKeywords ∪ expressionKeywords ∪ specificKeywords

extension String {
    /// return a swift representation of an identifier string (escaped if necessary)
    var swift: String {
        if let s = castables[self] { return s }
        guard !swiftKeywords.contains(self) else { return self + "_" }
        guard self != "void" else { return "Void" }
        guard self != "utf8" else { return "String" }
        guard let f = utf16.first else { return self }
        guard isalpha(Int32(f)) != 0 || Character(UnicodeScalar(f)) == "_" else { return "_" + self }
        return self
    }

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

    /// return the C type unwrapped and without const
    public var unwrappedCType: String {
        if let base = underlyingTypeForCPointer {
            let pointer = isCConst ? "UnsafePointer" : "UnsafeMutablePointer"
            let wrapped = pointer + "<\(base.unwrappedCType)>"
            return wrapped
        }
        return typeWithoutConst
    }

    /// return the Swift type for a given C type
    public var swiftRepresentationOfCType: String {
        return unwrappedCType.swift
    }

    /// return the string (value) cast to Swift
    func cast_as_swift(_ type: String) -> String {
        return cast_to_swift(self, forType: type)
    }

    /// return the string (value) cast to Swift
    func cast_as_c(_ type: String) -> String {
        return cast_from_swift(self, forType: type)
    }
}

/// convert the given C type to a Swift type
func toSwift(_ ctype: String) -> String {
    return ctype.swiftRepresentationOfCType
}


/// C type cast to swift
func cast_to_swift(_ value: String, forType t: String) -> String {
    if let s = castables[t] { return "\(s)(\(s == "Bool" ? value + " != 0" : value))" }
    return value
}

/// C type cast from swift
func cast_from_swift(_ value: String, forType t: String) -> String {
    if let s = reversecast[t] { return "\(s)(\(value))" }
    return value
}
