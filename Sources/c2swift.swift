//
//  c2swift.swift
//  gir2swift
//
//  Created by Rene Hexel on 29/04/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
#if os(Linux)
    import Glibc

    /// Linux is currently missing some basic String methods,
    /// so add them here
    extension String {
        /// return whether the receiver has the given prefix
        func hasPrefix(_ prefix: String) -> Bool {
            let p = prefix.utf16
            let s = utf16
            guard s.count >= p.count else { return false }

            var pi = p.makeIterator()
            var si = s.makeIterator()
            while let p = pi.next(), c = si.next() {
                guard p == c else { return false }
            }
            return true
        }

        /// return whether the receiver has the given suffix
        func hasSuffix(_ suffix: String) -> Bool {
            let u = suffix.utf16
            let v = utf16
            guard v.count >= u.count else { return false }

            var si = u.reversed().makeIterator()
            var ci = v.reversed().makeIterator()
            while let s = si.next(), c = ci.next() {
                guard s == c else { return false }
            }
            return true
        }
    }
#else
    import Darwin
#endif


private let castableScalars = [  "gint" : "CInt",    "glong" : "CLong",   "guint" : "CUnsignedInt", "char" : "CChar",
    "gint8"  : "Int8",  "guint8"  : "UInt8",  "gint16" : "Int16", "guint16" : "UInt16",
    "gint32" : "Int32", "guint32" : "UInt32", "gint64" : "Int64", "guint64" : "UInt64",
    "gulong" : "CUnsignedLong",  "gsize"   : "Int",  "gboolean" : "Bool", "goffset" : "Int"]
private let castablePointers = [ "gpointer" : "OpaquePointer" ]
private let reversePointers = castablePointers.reduce(Dictionary<String,String>()) {
    var dict = $0
    dict[$1.1] = $1.0
    return dict
}
private let reversecast = castableScalars.reduce(reversePointers) {
    var dict = $0
    dict[$1.1] = $1.0
    return dict
}
private let swiftReplacementsForC = [ "char" : "CChar", "int" : "CInt",
  "long" : "CLong", "long long" : "CLongLong", "unsigned long long" : "CUnsignedLongLong", "short" : "CShort",
  "double" : "CDouble", "float" : "CFloat", "long double" : "Double",
  "void" : "Void", "utf8" : "String", "va_list" : "CVaListPointer",
  "Error" : "ErrorType", "ErrorType" : "ErrorEnum" ]
private let reservedTypes: Set = ["String", "Array", "Optional", "Set", "Error", "ErrorProtocol"]
private let typeNames: Set = reservedTypes.union(reversecast.keys)
private let wsnlScalars: Set<UnicodeScalar> = [ " ", "\t", "\n"]
private let wsnl = wsnlScalars.map { UInt16($0.value) }.asSet

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

/// compare two UTF16Views for equality
public func ==(lhs: String.UTF16View, rhs: String.UTF16View) -> Bool {
    guard lhs.count == rhs.count else { return false }
    var li = lhs.makeIterator()
    var ri = rhs.makeIterator()
    while let l = li.next(), r = ri.next() {
        guard l == r else { return false }
    }
    return true
}
extension String.UTF16View: Equatable {}


extension String {
    /// remove all occurrences of the given substring
    func remove(_ subString: String) -> String {
        return remove(subString, subString.utf16)
    }
    private func remove(_ subString: String, _ utf16View: String.UTF16View) -> String {
        let k = Int(utf16View.distance(from: utf16View.startIndex, to: utf16View.endIndex))
        let u = utf16
        let n = u.count
        guard n >= k else { return self }
        let s = u.startIndex
        let e = u.endIndex
        for l in 0..<(n-k) {
            let i = u.index(s, offsetBy: l)
            let j = u.index(i, offsetBy: k)
            if u[i..<j] == utf16View {
                let str = String(u[s..<i]) + String(u[j..<e])
                return str.remove(subString, utf16View)
            }
        }
        return self
    }

    /// return whether the receiver contains the given substring
    func contains(_ subString: String) -> Bool {
        let utf16View = subString.utf16
        let k = Int(utf16View.distance(from: utf16View.startIndex, to: utf16View.endIndex))
        let u = utf16
        let n = u.count
        guard n >= k else { return false }
        let s = u.startIndex
        for l in 0..<(n-k) {
            let i = u.index(s, offsetBy: l)
            let j = u.index(i, offsetBy: k)
            if u[i..<j] == utf16View { return true }
        }
        return false
    }

    /// trim the characters in the given set of UTF16 values at either end of the string
    func trimmingCharacters(in: Set<UInt16>) -> String {
        let u = utf16
        let s = u.takeFrom(indexWhere: { !wsnl.contains($0) }).trimWhile { wsnl.contains($0) }
        return String(s)
    }

    /// return the string trimmed of white space at either end
    var trimmed: String { return trimmingCharacters(in: wsnl) }

    /// return a name with reserved Ref or Protocol suffixes escaped
    var typeEscaped: String {
        let nx: String
        if let sf = [ "Protocol", "Ref" ].filter({ self.hasSuffix($0) }).first {
            nx = stringByRemovingAnEquivalentNumberOfCharactersAs(suffix: sf) + "_" + sf
        } else {
            nx = self
        }
        return nx
    }

    /// return a valid Swift type for an underlying C type
    var swiftType: String {
        if let s = swiftReplacementsForC[self] { return s }
        guard let f = utf16.first else { return self }
        guard isalpha(Int32(f)) != 0 || Character(UnicodeScalar(f)) == "_" else { return "_" + self }
        return self
    }

    /// return a valid Swift name by appending '_' to a reserved name
    var swiftName: String {
        guard !reservedNames.contains(self) else { return self + "_" }
        return self
    }

    /// return a swift representation of an identifier string (escaped if necessary)
    var swift: String {
        if let s = castableScalars[self] { return s }
        if let s = castablePointers[self] { return s }
        if let s = swiftReplacementsForC[self] { return s }
        let s = swiftType
        guard !reservedTypes.contains(s) else { return s + "Type" }
        return s.swiftName
    }

    /// indicate whether the type represented by the receiver is a constant
    public var isCConst: Bool {
        let ns = trimmed
        return ns.hasPrefix("const ") || ns.contains(" const")
    }

    /// indicate whether the given string is a known g pointer type
    public var isCastablePointer: Bool { return castablePointers[self] != nil }

    /// indicate whether the given string is a knowns Swift pointer type
    public var isSwiftPointer: Bool { return hasSuffix("Pointer") }

    /// return the C type without a trailing "const"
    public var typeWithoutTrailingConst: String { return without(suffix: " const") }

    /// return the C type without a trailing "const"
    public var typeWithoutTrailingVolatile: String { return without(suffix: " volatile") }

    /// return the C type without a leading "const"
    public var typeWithoutLeadingConst: String { return without(prefix: "const ") }

    /// return the C type without a leading "volatile"
    public var typeWithoutLeadingVolatile: String { return without(prefix: "volatile ") }

    /// return the C type without a trailing "const" or "volatile"
    public var typeWithoutTrailingConstOrVolatile: String { return without(suffixes: [" const", " volatile"]) }

    /// return the C type without a leading or trailing "const"
    public var typeWithoutLeadingOrTrailingConst: String {
        return typeWithoutLeadingConst.typeWithoutTrailingConst
    }

    /// return the C type without a leading or trailing "volatile"
    public var typeWithoutLeadingOrTrailingVolatile: String {
        return typeWithoutLeadingVolatile.typeWithoutTrailingVolatile
    }

    /// return the C type without a leading or trailing "const" or "volatile"
    public var typeWithoutLeadingOrTrailingConstOrVolatile: String {
        return without(suffixes: [" const", " volatile"]).without(prefixes: ["const ", "volatile "])
    }

    /// return the C type without "const"
    public var typeWithoutConst: String { return without("const") }

    /// return the C type without "volatile"
    public var typeWithoutVolatile: String { return without("volatile") }

    /// return C type without the given word
    public func without(_ substring: String) -> String {
        let ns = remove(substring)
        return ns.trimmed
    }

    /// return C type without the given prefix
    public func without(prefix: String) -> String {
        let ns = trimmed
        guard ns.hasPrefix(prefix) else { return ns }
        let len = prefix.characters.count
        let cs = ns.characters
        let s = cs.index(cs.startIndex, offsetBy: len)
        let e = cs.endIndex
        return String(ns.characters[s..<e]).without(prefix: prefix)
    }

    /// return C type without any of the given prefixes
    public func without(prefixes: [String]) -> String {
        let ns = trimmed
        guard let prefix = prefixes.lazy.filter({ ns.hasPrefix($0) }).first else { return ns }
        let len = prefix.characters.count
        let cs = ns.characters
        let s = cs.index(cs.startIndex, offsetBy: len)
        let e = cs.endIndex
        return String(ns.characters[s..<e]).without(prefixes: prefixes)
    }

    /// return C type without the given suffix
    public func without(suffix: String) -> String {
        let ns = trimmed
        guard ns.hasSuffix(suffix) else { return ns }
        let len = suffix.characters.count
        let cs = ns.characters
        let s = cs.startIndex
        let e = cs.index(s, offsetBy: cs.count - len)
        return String(ns.characters[s..<e]).without(suffix: suffix)
    }

    /// return C type without any of the given suffixes
    public func without(suffixes: [String]) -> String {
        let ns = trimmed
        guard let suffix = suffixes.lazy.filter({ ns.hasSuffix($0) }).first else { return ns }
        let len = suffix.characters.count
        let cs = ns.characters
        let s = cs.startIndex
        let e = cs.index(s, offsetBy: cs.count - len)
        return String(ns.characters[s..<e]).without(suffixes: suffixes)
    }

    /// return whether the untrimmed string is a C pointer
    var isTrimmedCPointer: Bool { return self.hasSuffix("*") }


    /// return whether the untrimmed string is a gpointer or gconstpointer
    var isTrimmedGPointer: Bool { return self == "gpointer" || self == "gconstpointer" }

    /// return whether the untrimmed string is a pointer
    var isTrimmedPointer: Bool { return isTrimmedGPointer || isTrimmedCPointer }

    /// return whether the underlying C type is a pointer
    public var isCPointer: Bool {
        return typeWithoutTrailingConstOrVolatile.trimmed.isTrimmedCPointer
    }

    /// return whether the underlying C type is a gpointer
    public var isGPointer: Bool {
        return typeWithoutTrailingConstOrVolatile.trimmed.isTrimmedGPointer
    }

    /// return whether the underlying C type is a pointer of any kind
    public var isPointer: Bool {
        return typeWithoutTrailingConstOrVolatile.trimmed.isTrimmedPointer
    }

    /// return the underlying C type for a pointer, nil if not a pointer
    public var underlyingTypeForCPointer: String? {
        guard isCPointer else { return nil }
        let ns = typeWithoutTrailingConstOrVolatile
        let cs = ns.characters
        let s = cs.startIndex
        let e = cs.index(before: cs.endIndex)
        return String(cs[s..<e])
    }

    /// return the C type unwrapped and converted to Swift
    public func unwrappedCTypeWithCount(_ pointerCount: Int = 0, _ constCount: Int = 0) -> (gType: String, swift: String, pointerCount: Int, constCount: Int, innerType: String) {
        if let base = underlyingTypeForCPointer {
            let (pointer, cc) = isCConst ? ("UnsafePointer", constCount+1) : ("UnsafeMutablePointer", constCount)
            let t = base.unwrappedCTypeWithCount(pointerCount+1, cc)
            let wrappedOrig = pointer + "<\(t.gType)>"
            let wrappedSwift = pointer + "<\(t.swift)>"
            return (gType: wrappedOrig, swift: wrappedSwift, pointerCount: t.pointerCount, constCount: t.constCount, innerType: t.innerType)
        }
        let t = trimmed.typeWithoutLeadingOrTrailingConstOrVolatile
        let swiftVersionOfCType = t.swiftType
        return (gType: swiftVersionOfCType, swift: t.swift, pointerCount: pointerCount, constCount: constCount, innerType: t)
    }

    /// return the inner type of a C type (without pointers and const)
    public var innerCType: String { return unwrappedCTypeWithCount().innerType }

    /// return the swift representation of the inner type of a C type (without pointers and const)
    public var innerGType: String { return innerCType.swiftType }

    /// return the common swift type used for the inner type of a C type (without pointers and const)
    public var innerSwiftType: String { return innerCType.swiftType }

    /// return the C type unwrapped, without const, and converted to Swift
    public var unwrappedCType: String { return unwrappedCTypeWithCount().gType }

    /// return the Swift type common for a given C type
    public var swiftRepresentationOfCType: String { return unwrappedCTypeWithCount().swift }

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
    if let s = castableScalars[t] { return "\(s)(\(s == "Bool" ? value + " != 0" : value))" }
    return value
}

/// C type cast from swift
func cast_from_swift(_ value: String, forCType t: String) -> String {
    if let s = castableScalars[t] { return "\(t)(\(s == "Bool" ? value + " ? 1 : 0": value))"  }
    return value
}

typealias TypeCastTuple = (c: String, swift: String, toC: String, toSwift: String)

/// return a C+Swift type pair
func typeCastTuple(_ ctype: String, _ swiftType: String, varName: String = "rv", forceCast: Bool = false) -> TypeCastTuple {
    let u = ctype.unwrappedCTypeWithCount()
    let nPointers = u.pointerCount + ((swiftType.isPointer || ctype.isPointer) ? 1 : 0)
    let ct = u.gType != "" ? u.gType : swiftType
    let st = u.swift != "" ? u.swift : ct
    let cast = "cast(\(varName))"
    let cswift: TypeCastTuple
    switch (ct, st) {
    case ("utf8", _), (_, "String"):
        cswift = nPointers == 1 ? (ct, st, varName, cast) : (ct, "[String]", varName, "asStringArray(\(cast))")
        if nPointers > 2 {
            fputs("Warning: unhandled pointer count of \(nPointers) for '\(ct)' as '\(st)'", stderr)
        }
    default:
        cswift = (ct, st,
            forceCast || nPointers != 0 ? cast : cast_from_swift(varName, forCType: ct),
            forceCast || nPointers != 0 ? cast : cast_to_swift(varName, forCType: ct))
    }
    return cswift
}
