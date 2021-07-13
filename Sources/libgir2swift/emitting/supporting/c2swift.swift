//
//  c2swift.swift
//  gir2swift
//
//  Created by Rene Hexel on 29/04/2016.
//  Copyright © 2016, 2017, 2018, 2019, 2020 Rene Hexel. All rights reserved.
//

import Foundation

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

public extension String {
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
        self.first?.isLetter == false && self.first != "_"
            ? "_" + self
            : self
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
}

@usableFromInline let splittablePrefixes = [ "after_", "before_", "for_", "from_", "in_", "of_", "with_", "within_" ]

extension StringProtocol {
    /// return a valid Swift name by quoting a reserved name
    @usableFromInline var swiftQuoted: String {
        let s = String(self)
        guard !reservedNames.contains(s) else { return "`" + self + "`" }
        return s.swiftIdentifier
    }
}
