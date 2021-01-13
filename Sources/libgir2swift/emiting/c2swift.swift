//
//  c2swift.swift
//  gir2swift
//
//  Created by Rene Hexel on 29/04/2016.
//  Copyright © 2016, 2017, 2018, 2019, 2020 Rene Hexel. All rights reserved.
//
#if os(Linux)
    import Glibc

    /// Linux is currently missing some basic String methods,
    /// so add them here
    public extension String {
        /// return whether the receiver has the given prefix
        func hasPrefix(_ prefix: String) -> Bool {
            let p = prefix.utf8
            let s = utf8
            guard s.count >= p.count else { return false }

            var pi = p.makeIterator()
            var si = s.makeIterator()
            while let p = pi.next(), let c = si.next() {
                guard p == c else { return false }
            }
            return true
        }

        /// return whether the receiver has the given suffix
        func hasSuffix(_ suffix: String) -> Bool {
            let u = suffix.utf8
            let v = utf8
            guard v.count >= u.count else { return false }

            var si = u.reversed().makeIterator()
            var ci = v.reversed().makeIterator()
            while let s = si.next(), let c = ci.next() {
                guard s == c else { return false }
            }
            return true
        }
    }
#else
    import Darwin
#endif


/// Scalar C types that have an equivalent in Swift
private let castableScalars = [  "gint" : "CInt",    "glong" : "CLong",   "guint" : "CUnsignedInt", "char" : "CChar",
    "gint8"  : "Int8",  "guint8"  : "UInt8",  "gint16" : "Int16", "guint16" : "UInt16",
    "gint32" : "Int32", "guint32" : "UInt32", "gint64" : "Int64", "guint64" : "UInt64",
    "gulong" : "CUnsignedLong",  "gsize"   : "Int",  "gboolean" : "Bool", "goffset" : "Int"]
/// C pointer types that have an equivalent in Swift
private let castablePointers = [ "gpointer" : "UnsafeMutableRawPointer" ]
/// Swift pointer types that have an equivalent in C
private let reversePointers = castablePointers.reduce(Dictionary<String,String>()) {
    var dict = $0
    dict[$1.1] = $1.0
    return dict
}
/// Scalar Swift types that have an equivalent in C
private let reversecast = castableScalars.reduce(reversePointers) {
    var dict = $0
    dict[$1.1] = $1.0
    return dict
}

/// Swift fundamental type names
private let swiftFundamentalsForC = [
    "char" : "CChar", "unsigned char" : "CUnsignedChar",
    "int" : "CInt", "unsigned int" : "CUnsignedInt", "unsigned" : "CUnsignedInt",
    "long" : "CLong", "unsigned long" : "CUnsignedLong",
    "long long" : "CLongLong", "unsigned long long" : "CUnsignedLongLong",
    "short" : "CShort", "unsigned short" : "CUnsignedShort",
    "double" : "CDouble", "float" : "CFloat", "long double" : "CLongDouble",
    "void" : "Void",
    "int8_t" : "Int8", "uint8_t" : "UInt8",
    "int16_t" : "Int16", "uint16_t" : "UInt16",
    "int32_t" : "Int32", "uint32_t" : "UInt32",
    "int64_t" : "Int64", "uint64_t" : "UInt64"
]
/// Swift fundamental, scalar type name replacements
private let swiftFullTypesForC = swiftFundamentalsForC.merging([
    "va_list" : "CVaListPointer",
    "UnsafeMutablePointer<Void>" : "UnsafeMutableRawPointer",
    "UnsafeMutablePointer<Void>!" : "UnsafeMutableRawPointer!",
    "UnsafeMutablePointer<Void>?" : "UnsafeMutableRawPointer?",
    "UnsafePointer<Void>" : "UnsafeRawPointer",
    "UnsafePointer<Void>!" : "UnsafeRawPointer!",
    "UnsafePointer<Void>?" : "UnsafeRawPointer?",
]) { $1 }

/// Swift type equivalents for C types
private let swiftReplacementsForC = swiftFullTypesForC.merging([
    "utf8" : "String", "filename" : "String",
    "Error" : "GLibError"
]) { $1 }

/// Mapping that allows casting from original C types to more idiomatic Swift types
/// FIXME: these types only work correctly on 64bit systems
private let swiftConvenience = [ "CInt" : "Int", "CUnsignedInt" : "Int",
  "CLong" : "Int", "CUnsignedLong" : "Int", "CLongLong" : "Int", "CUnsignedLongLong" : "Int",
  "CShort" : "Int", "CUnsignedShort" : "Int", "CDouble" : "Double", "CFloat" : "Double",
  "gfloat" : "Float", "gdouble" : "Double"  ]

/// Idiomatic Swift type equivalents for C types
private let swiftIdiomaticReplacements: [ String : String] = swiftReplacementsForC.mapValues {
    guard let replacement = swiftConvenience[$0] else { return $0 }
    return replacement
}

/// Verbatim Swift type equivalents for C types
private let swiftVerbatimReplacements = swiftReplacementsForC.mapValues { $0 == "String" ? "UnsafePointer<CChar>?" : $0 }

/// Verbatim Swift type equivalents for C types
private let swiftVerbatimIdiomaticReplacements = swiftIdiomaticReplacements.mapValues { $0 == "String" ? "UnsafePointer<CChar>?" : $0 }

/// Types that already exist in Swift and therefore need to be treated specially
private let reservedTypes: Set = ["String", "Array", "Optional", "Set", "Error", "ErrorProtocol"]
/// Known Swift type names
private let typeNames: Set = reservedTypes.union(reversecast.keys)
/// UnicodeScalars representing whitespaces and newlines
private let wsnlScalars: Set<UnicodeScalar> = [ " ", "\t", "\n"]
/// Set of whitespace and newline ASCII/UTF8 codes
private let wsnl = Set(wsnlScalars.map { UInt8($0.value) })

/// Swift keyword for `true` Boolean values
private let trueS  = "true"
/// Swift keyword for `false` Boolean values
private let falseS = "false"
/// Swift keyword for `nil` values
private let nilS   = "nil"
/// Keywords reserved for declarations in Swift
private let declarationKeywords: Set = ["associatedtype", "class", "deinit", "enum", "extension", "func", "import", "init", "inout", "internal", "let", "operator", "private", "protocol", "public", "static", "struct", "subscript", "typealias", "var"];
/// Keywords reserved for statements in Swift
private let statementKeywords: Set = ["break", "case", "continue", "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch", "where", "while"]
/// Keywords reserved for expressions in Swift
private let expressionKeywords: Set = ["as", "catch", "dynamicType", "false", "is", "nil", "rethrows", "super", "self", "Self", "throw", "throws", "true", "try", "#column", "#file", "#function", "#line."]
/// Keywords with specific meanings in Swift
private let specificKeywords: Set = ["associativity", "convenience", "dynamic", "didSet", "final", "infix", "indirect", "lazy", "left", "mutating", "none", "nonmutating", "optional", "override", "postfix", "precedence", "prefix", "Protocol", "required", "right", "Type", "unowned", "weak", "willSet"]

infix operator ∪: LogicalDisjunctionPrecedence

/// Set union operator
/// - Parameters:
///   - left: lefthand side set to form a union from
///   - right: righthand side set to form a union from
@inlinable
func ∪<T>(left: Set<T>, right: Set<T>) -> Set<T> {
    return left.union(right)
}

/// Set union operator
/// - Parameters:
///   - left: lefthand side set to form a union from
///   - right: set element to include in the union
@inlinable
func ∪<T>(left: Set<T>, right: T) -> Set<T> {
    return left.union([right])
}

/// Set union operator
/// - Parameters:
///   - left: set element to include in the union
///   - right: righthand side set to form a union from
@inlinable
func ∪<T>(left: T, right: Set<T>) -> Set<T> {
    return Set<T>(arrayLiteral: left).union(right)
}

/// List of all Swiftwords in Swift
let swiftKeywords = declarationKeywords ∪ statementKeywords ∪ expressionKeywords ∪ specificKeywords
/// List of all reserved names in Swift
let reservedNames = typeNames ∪ swiftKeywords

extension String.UTF8View: Equatable {
    /// compare two UTF8Views for equality
    public static func ==(lhs: String.UTF8View, rhs: String.UTF8View) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var li = lhs.makeIterator()
        var ri = rhs.makeIterator()
        while let l = li.next(), let r = ri.next() {
            guard l == r else { return false }
        }
        return true
    }
}


public extension String {
    /// recursively remove all occurrences of the given substring
    /// Note: this does not recursively remove substrings that span
    /// substrings partitioned by a previous removal.  E.g.,
    /// "TesTestt".remove("Test") will return "Test" rather than an empty string!
    func remove(_ subString: String) -> String {
        return String(self[startIndex..<endIndex].remove(subString))
    }

    /// return whether the receiver contains the given substring
    func contains(_ subString: String) -> Bool {
        let k = subString.distance(from: subString.startIndex, to: subString.endIndex)
        let n = count
        guard n >= k else { return false }
        let s = startIndex
        for l in 0...(n-k) {
            let i = index(s, offsetBy: l)
            let j = index(i, offsetBy: k)
            if self[i..<j] == subString { return true }
        }
        return false
    }

    /// trim the characters in the given set of UTF8 values at either end of the string
    func trimmingCharacters(in: Set<UInt8>) -> String {
        let u = utf8
        let s = u.takeFrom(indexWhere: { !wsnl.contains($0) }).trimWhile { wsnl.contains($0) }
        return String(Substring(s))
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

    /// Return a string that starts with an alpha or underscore character
    var swiftIdentifier: String {
        guard let f = utf8.first else { return self }
        let u = UnicodeScalar(f)
        guard isalpha(Int32(f)) != 0 || Character(u) == "_" else { return "_" + self }
        return self
    }

    /// return a valid Swift type for an underlying C type
    var validSwift: String {
        if let s = swiftFundamentalsForC[self] { return s }
        return swiftIdentifier
    }

    /// return a valid, full Swift type (including pointers) for an underlying C type
    var validFullSwift: String {
        if let s = swiftFullTypesForC[self] { return s }
        return swiftIdentifier
    }

    /// return a valid Swift type for an underlying C type
    var swiftType: String {
        if let s = swiftReplacementsForC[self] { return s }
        return swiftIdentifier
    }

    /// Assuming the receiver is a Swift type,
    /// return an idiomatic type corresponding to the receiver
    var idiomatic: String {
        guard let idiomatic = swiftConvenience[self] else { return self }
        return idiomatic
    }

    /// return a valid, idiomatic Swift type for an underlying C type
    var swiftTypeIdiomatic: String {
        if let s = swiftIdiomaticReplacements[self] { return s }
        return swiftIdentifier
    }
    
    /// return a valid, verbatim Swift type for an underlying C type
    var swiftTypeVerbatim: String {
        if let s = swiftVerbatimReplacements[self] { return s }
        return swiftIdentifier
    }
    
    /// return an idiomatic, verbatim Swift type for an underlying C type
    var swiftTypeVerbatimIdiomatic: String {
        if let s = swiftVerbatimIdiomaticReplacements[self] { return s }
        return swiftIdentifier
    }

    /// return a valid Swift name by appending '_' to a reserved name
    var swiftName: String {
        guard !reservedNames.contains(self) else { return self + "_" }
        return swiftIdentifier
    }

    /// return a valid Swift name by quoting a reserved name
    var swiftQuoted: String {
        guard !reservedNames.contains(self) else { return "`" + self + "`" }
        return swiftIdentifier
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

    /// return an idiomatic swift representation of an identifier string (escaped if necessary)
    var swiftIdiomatic: String {
        if let s = castableScalars[self] { return s }
        if let s = castablePointers[self] { return s }
        if let s = swiftIdiomaticReplacements[self] { return s }
        let s = swiftType
        guard !reservedTypes.contains(s) else { return s + "Type" }
        return s.swiftName
    }
    
    /// return a verbatim swift representation of an identifier string (escaped if necessary)
    var swiftVerbatim: String {
        if let s = castableScalars[self] { return s }
        if let s = castablePointers[self] { return s }
        if let s = swiftVerbatimReplacements[self] { return s }
        let s = swiftType
        guard !reservedTypes.contains(s) else { return s + "Type" }
        return s.swiftName
    }

    /// return a verbatim, idiomatic swift representation of an identifier string (escaped if necessary)
    var swiftVerbatimIdiomatic: String {
        if let s = castableScalars[self] { return s }
        if let s = castablePointers[self] { return s }
        if let s = swiftVerbatimIdiomaticReplacements[self] { return s }
        let s = swiftType
        guard !reservedTypes.contains(s) else { return s + "Type" }
        return s.swiftName
    }

    /// indicate whether the type represented by the receiver is a constant
    var isCConst: Bool {
        let ns = trimmed
        return ns.hasPrefix("const ") || ns.contains(" const")
    }

    /// indicate whether the given string is a known g pointer type
    var isCastablePointer: Bool { return castablePointers[self] != nil }

    /// indicate whether the given string is a knowns Swift pointer type
    var isSwiftPointer: Bool { return hasSuffix("Pointer") }

    /// return the C type without a trailing "const"
    var typeWithoutTrailingConst: String { return without(suffix: " const") }

    /// return the C type without a trailing "const"
    var typeWithoutTrailingVolatile: String { return without(suffix: " volatile") }

    /// return the C type without a leading "const"
    var typeWithoutLeadingConst: String { return without(prefix: "const ") }

    /// return the C type without a leading "volatile"
    var typeWithoutLeadingVolatile: String { return without(prefix: "volatile ") }

    /// return the C type without a trailing "const" or "volatile"
    var typeWithoutTrailingConstOrVolatile: String { return without(suffixes: [" const", " volatile"]) }

    /// return the C type without a leading or trailing "const"
    var typeWithoutLeadingOrTrailingConst: String {
        return typeWithoutLeadingConst.typeWithoutTrailingConst
    }

    /// return the C type without a leading or trailing "volatile"
    var typeWithoutLeadingOrTrailingVolatile: String {
        return typeWithoutLeadingVolatile.typeWithoutTrailingVolatile
    }

    /// return the C type without a leading or trailing "const" or "volatile"
    var typeWithoutLeadingOrTrailingConstOrVolatile: String {
        return without(suffixes: [" const", " volatile"]).without(prefixes: ["const ", "volatile "])
    }

    /// return the C type without "const"
    var typeWithoutConst: String { return without("const") }

    /// return the C type without "volatile"
    var typeWithoutVolatile: String { return without("volatile") }

    /// return C type without the given word
    func without(_ substring: String) -> String {
        let ns = remove(substring)
        return ns.trimmed
    }

    /// return C type without the given prefix
    func without(prefix: String) -> String {
        let ns = trimmed
        guard ns.hasPrefix(prefix) else { return ns }
        let len = prefix.count
        let s = ns.index(ns.startIndex, offsetBy: len)
        let e = ns.endIndex
        return String(ns[s..<e]).without(prefix: prefix)
    }

    /// return C type without any of the given prefixes
    func without(prefixes: [String]) -> String {
        let ns = trimmed
        guard let prefix = prefixes.lazy.filter({ ns.hasPrefix($0) }).first else { return ns }
        let len = prefix.count
        let s = ns.index(ns.startIndex, offsetBy: len)
        let e = ns.endIndex
        return String(ns[s..<e]).without(prefixes: prefixes)
    }

    /// return C type without the given suffix
    func without(suffix: String) -> String {
        let ns = trimmed
        guard ns.hasSuffix(suffix) else { return ns }
        let len = suffix.count
        let s = ns.startIndex
        let e = ns.index(s, offsetBy: ns.count - len)
        return String(ns[s..<e]).without(suffix: suffix)
    }

    /// return C type without any of the given suffixes
    func without(suffixes: [String]) -> String {
        let ns = trimmed
        guard let suffix = suffixes.lazy.filter({ ns.hasSuffix($0) }).first else { return ns }
        let len = suffix.count
        let s = ns.startIndex
        let e = ns.index(s, offsetBy: ns.count - len)
        return String(ns[s..<e]).without(suffixes: suffixes)
    }

    /// return whether the untrimmed string is a C pointer
    var isTrimmedCPointer: Bool { return self.hasSuffix("*") }


    /// return whether the untrimmed string is a gpointer or gconstpointer
    var isTrimmedGPointer: Bool { return self == "gpointer" || self == "gconstpointer" }

    /// return whether the untrimmed string is a pointer
    var isTrimmedPointer: Bool { return isTrimmedGPointer || isTrimmedCPointer }

    /// return whether the underlying C type is a pointer
    var isCPointer: Bool {
        return typeWithoutTrailingConstOrVolatile.trimmed.isTrimmedCPointer
    }

    /// return whether the underlying C type is a gpointer
    var isGPointer: Bool {
        return typeWithoutTrailingConstOrVolatile.trimmed.isTrimmedGPointer
    }

    /// return whether the underlying C type is a pointer of any kind
    var isPointer: Bool {
        return typeWithoutTrailingConstOrVolatile.trimmed.isTrimmedPointer
    }

    /// return the underlying C type for a pointer, nil if not a pointer
    var underlyingTypeForCPointer: String? {
        guard isCPointer else { return nil }
        let ns = typeWithoutTrailingConstOrVolatile
        let s = ns.startIndex
        let e = ns.index(before: ns.endIndex)
        return String(ns[s..<e])
    }

    /// return the C type unwrapped and converted to Swift
    /// - Parameters:
    ///   - pointerCount: the number of pointer indirections to deal with
    ///   - constCount: the number of consts
    ///   - optionalTail: the tail to add, e.g. "?" for optional, "!", for a force-unwrapped optional, or "" for a non-optional pointer
    /// - Returns: Tuple of the Swift version of the C type, the Swift-encoded version of the inner type, the pointer and const counts, as well as the inner type
    func unwrappedCTypeWithCount(_ pointerCount: Int = 0, _ constCount: Int = 0, optionalTail: String = "!") -> (gType: String, swift: String, pointerCount: Int, constCount: Int, innerType: String) {
        if let base = underlyingTypeForCPointer {
            let (pointer, cc) = isCConst ? ("UnsafePointer", constCount+1) : ("UnsafeMutablePointer", constCount)
            let t = base.unwrappedCTypeWithCount(pointerCount+1, cc, optionalTail: "?")
            let wrappedOrig = pointer + "<\(t.gType)>" + optionalTail
            let wrappedSwift: String
            if t.swift == "Void" {
                wrappedSwift = pointer == "UnsafePointer" ? "UnsafeRawPointer" : "UnsafeMutableRawPointer"
            } else {
                wrappedSwift = pointer + "<\(t.swift)>" + optionalTail
            }
            return (gType: wrappedOrig, swift: wrappedSwift, pointerCount: t.pointerCount, constCount: t.constCount, innerType: t.innerType)
        }
        let t = trimmed.typeWithoutLeadingOrTrailingConstOrVolatile
        let swiftVersionOfCType = t.swiftType
        return (gType: swiftVersionOfCType, swift: t.swift, pointerCount: pointerCount, constCount: constCount, innerType: t)
    }

    /// return the inner type of a C type (without pointers and const)
    var innerCType: String { return unwrappedCTypeWithCount().innerType }

    /// return the swift representation of the inner type of a C type (without pointers and const)
    var innerGType: String { return innerCType.swiftType }

    /// return the common swift type used for the inner type of a C type (without pointers and const)
    var innerSwiftType: String { return innerCType.swiftType }

    /// return the C type unwrapped, without const, and converted to Swift
    var unwrappedCType: String { return unwrappedCTypeWithCount().gType }

    /// return the Swift type common for a given C type
    var swiftRepresentationOfCType: String { return unwrappedCTypeWithCount().swift }

    /// return a split argument name based on splittable prefixes such as "for", "from", "in"
    @inlinable var argumentSplit: (prefix: Substring, arg: Substring) {
        guard let i = splittablePrefixIndex(from: splittablePrefixes), i != endIndex else { return ("", self[startIndex..<endIndex]) }
        let e = index(before: i)
        return (prefix: self[startIndex..<e], arg: self[i..<endIndex])
    }

    /// Return the splittable prefix
    /// - Parameter prefixes: the prefixes to check for
    /// - Returns: The splittable substring index
    @inlinable func splittablePrefixIndex<S: StringProtocol>(from prefixes: [S]) -> Index? {
        for prefix in prefixes {
            if hasPrefix(prefix) {
                return index(startIndex, offsetBy: prefix.count)
            }
        }
        return nil
    }
}

@usableFromInline let splittablePrefixes = [ "after_", "before_", "for_", "from_", "in_", "of_", "with_", "within_" ]

extension Substring {
    /// recursively remove all occurrences of the given substring
    /// Note: this does not recursively remove substrings that span
    /// substrings partitioned by a previous removal.  E.g.,
    /// "TesTestt".remove("Test") will return "Test" rather than an empty string!
    func remove(_ subString: String) -> Substring {
        let k = subString.distance(from: subString.startIndex, to: subString.endIndex)
        let n = count
        guard n >= k else { return self }
        let s = startIndex
        let e = endIndex
        for l in 0...(n-k) {
            let i = index(s, offsetBy: l)
            let j = index(i, offsetBy: k)
            guard self[i..<j] != subString else {
                let left = self[s..<i]
                let right = self[j..<e].remove(subString)
                let str = left + right
                return str
            }
        }
        return self
    }

    /// return a valid Swift name by quoting a reserved name
    @usableFromInline var swiftQuoted: String {
        let s = String(self)
        guard !reservedNames.contains(s) else { return "`" + self + "`" }
        return s.swiftIdentifier
    }

    /// return the Swift camel case name, quoted if necessary
    @usableFromInline var camelQuoted: String { self.camelCase.swiftQuoted }
}

/// convert the given C type to a Swift type
func toSwift(_ ctype: String) -> String {
    return ctype.swiftRepresentationOfCType
}
