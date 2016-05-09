//
//  c2swift.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 29/04/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
import Foundation

private let castables = [ "gint" : "Int", "guint" : "UInt", "glong" : "Int", "char" : "Int8",
    "gint8"  : "Int8",  "guint8"  : "UInt8",  "gint16" : "Int16", "guint16" : "UInt16",
    "gint32" : "Int32", "guint32" : "UInt32", "gint64" : "Int64", "guint64" : "UInt64",
    "gulong" : "UInt",  "gsize"   : "Int",  "gboolean" : "Bool", "gpointer" : "COpaquePointer" ]
private let reversecast = castables.reduce(Dictionary<String,String>()) {
    var dict = $0
    dict[$1.1] = $1.0
    return dict
}
private let swiftReplacementsForC = [ "char" : "CChar", "int" : "CInt", "void" : "Void", "utf8" : "String", "va_list" : "CVaListPointer" ]
private let reservedTypes: Set = ["String", "Array", "Optional", "Set"]
private let typeNames: Set = reservedTypes.union(reversecast.keys)
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
let reservedNames = typeNames ∪ swiftKeywords

extension String {
    /// return a valid Swift type for an underlying C type
    var swiftType: String {
        if let s = swiftReplacementsForC[self] { return s }
        return self
    }

    /// return a swift representation of an identifier string (escaped if necessary)
    var swift: String {
        if let s = castables[self] { return s }
        if let s = swiftReplacementsForC[self] { return s }
        guard !reservedNames.contains(self) else { return self + "_" }
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

    /// return the C type without a leading "const"
    public var typeWithoutLeadingConst: String {
        let ns = stringByTrimmingCharactersInSet(wsnl)
        let p: String
        if (ns.hasPrefix("const ")) {
            let cs = ns.characters
            let s = cs.startIndex.advancedBy(5)
            let e = cs.endIndex
            p = String(ns.characters[s..<e])
        } else {
            p = ns
        }
        return p
    }

    /// return the C type without a leading or trailing "const"
    public var typeWithoutLeadingOrTrailingConst: String {
        return typeWithoutLeadingConst.typeWithoutTrailingConst
    }

    /// return the C type without "const"
    public var typeWithoutConst: String {
        let ns = stringByReplacingOccurrencesOfString("const", withString: "")
        return ns.stringByTrimmingCharactersInSet(wsnl)
    }

    /// return whether the untrimmed string is a C pointer
    var isTrimmedCPointer: Bool { return self.hasSuffix("*") }


    /// return whether the untrimmed string is a gpointer or gconstpointer
    var isTrimmedGPointer: Bool { return self == "gpointer" || self == "gconstpointer" }

    /// return whether the untrimmed string is a pointer
    var isTrimmedPointer: Bool { return isTrimmedGPointer || isTrimmedCPointer }

    /// return whether the underlying C type is a pointer
    public var isCPointer: Bool {
        return typeWithoutTrailingConst.stringByTrimmingCharactersInSet(wsnl).isTrimmedCPointer
    }

    /// return whether the underlying C type is a gpointer
    public var isGPointer: Bool {
        return typeWithoutTrailingConst.stringByTrimmingCharactersInSet(wsnl).isTrimmedGPointer
    }

    /// return whether the underlying C type is a pointer of any kind
    public var isPointer: Bool {
        return typeWithoutTrailingConst.stringByTrimmingCharactersInSet(wsnl).isTrimmedPointer
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

    public func unwrappedCTypeWithCount(_ pointerCount: Int = 0, _ constCount: Int = 0) -> (cType: String, pointerCount: Int, constCount: Int) {
        if let base = underlyingTypeForCPointer {
            let (pointer, cc) = isCConst ? ("UnsafePointer", constCount+1) : ("UnsafeMutablePointer", constCount)
            let t = base.unwrappedCTypeWithCount(pointerCount+1, cc)
            let wrapped = pointer + "<\(t.cType)>"
            return (cType: wrapped, pointerCount: t.pointerCount, constCount: t.constCount)
        }
        return (cType: typeWithoutLeadingOrTrailingConst.swiftType, pointerCount: pointerCount, constCount: constCount)
    }

    /// return the C type unwrapped and without const
    public var unwrappedCType: String {
        return unwrappedCTypeWithCount().cType
    }

    /// return the Swift type for a given C type
    public var swiftRepresentationOfCType: String {
        return unwrappedCType.swift
    }

    /// return the string (value) cast to Swift
    func cast_as_swift(_ type: String) -> String {
        return cast_to_swift(self, forCType: type)
    }

    /// return the string (value) cast to Swift
    func cast_as_c(_ cType: String) -> String {
        return cast_from_swift(self, forCType: cType)
    }
}

/// convert the given C type to a Swift type
func toSwift(_ ctype: String) -> String {
    return ctype.swiftRepresentationOfCType
}


/// C type cast to swift
func cast_to_swift(_ value: String, forCType t: String) -> String {
    if let s = castables[t] { return "\(s)(\(s == "Bool" ? value + " != 0" : value))" }
    return value
}

/// C type cast from swift
func cast_from_swift(_ value: String, forCType t: String) -> String {
    if let s = castables[t] { return "\(t)(\(s == "Bool" ? value + " ? 1 : 0": value))"  }
    return value
}

typealias TypeCastTuple = (c: String, swift: String, toC: String, toSwift: String)

/// return a C+Swift type pair
func typeCastTuple(_ ctype: String, _ swiftType: String, varName: String = "rv") -> TypeCastTuple {
    let u = ctype.unwrappedCTypeWithCount()
    let ct = u.cType != "" ? u.cType : swiftType
    let st = ct.swift
    let cast = "cast(\(varName))"
    let cswift: TypeCastTuple
    switch (ct, st) {
    case ("utf8", _), (_, "String"):
        cswift = u.pointerCount == 1 ? (ct, st, varName, cast) : (ct, "[String]", varName, "asStringArray(\(cast))")
        if u.pointerCount > 2 {
            fputs("Warning: unhandled pointer count of \(u.pointerCount) for '\(ct)' as '\(st)'", stderr)
        }
    default:
        cswift = (ct, st,
            u.pointerCount == 0 ? cast_from_swift(varName, forCType: ct) : cast,
            u.pointerCount == 0 ?   cast_to_swift(varName, forCType: ct) : cast)
    }
    return cswift
}
