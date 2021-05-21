//
//  String+Substring.swift
//  gir2swift
//
//  Created by Rene Hexel on 25/04/2016.
//  Copyright © 2016, 2017, 2018, 2019, 2020 Rene Hexel. All rights reserved.
//
//
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/// UTF8 representation of an underscore
@usableFromInline let underscore = "_".utf8.first!

/// UTF8 representation of a minus sign
@usableFromInline let minus = "-".utf8.first!

public extension String {
    /// Dotted prefix for the string (empty if none)
    @inlinable var dottedPrefix: Substring {
        guard let e = firstIndex(of: ".") else { return "" }
        let s = startIndex
        return self[s...e]
    }

    /// return the unprefixed version of the string
    /// (e.g. type without namespace)
    @inlinable var unprefixed: String {
        guard let suffix = components(separatedBy: ".").last else { return self }
        return suffix
    }

    /// return a prefixed version of the string
    @inlinable func prefixed(with prefix: String) -> String {
        guard !prefix.isEmpty else { return self }
        return prefix + "." + self
    }

    /// return the string resulting from removing the given suffix
    @inlinable func stringByRemoving(suffix s: String) -> String? {
        let len = s.count
        return hasSuffix(s) ? String(self[startIndex..<index(endIndex, offsetBy: -len)]) : nil
    }

    /// return the string resulting from removing the same number of
    /// characters as the given substring.  This will crash if the
    /// receiver is not long enough to have the corresponding number of
    /// characters removed
    @inlinable func stringByRemovingAnEquivalentNumberOfCharactersAs(suffix s: String) -> String {
        let len = s.count
        return String(self[startIndex..<index(endIndex, offsetBy: -len)])
    }

    /// return the substring after the first occurrence of the given character
    @inlinable func afterFirst(separator s: Character = "_") -> String? {
        let components = split(separator: s)
        guard components.count > 1 else { return nil }
        return components[components.index(after: components.startIndex)..<components.endIndex].joined(separator: String(s))
    }

    /// return the capidalised name of the receiver,
    /// without changing the case of subsequent letters
    /// Note: this is different from `capitalized` in the Swift standard library
    @inlinable var capitalised: String {
        guard let c = first, c.isLowercase else { return self }
        return c.uppercased() + self[index(after: startIndex)...]
    }

    /// return the de-capidalised (lower-case first character) name of the receiver
    @inlinable var deCapitalised: String {
        guard let c = first, c.isUppercase else { return self }
        return c.lowercased() + self[index(after: startIndex)...]
    }

    /// convert a string with separators to camel case
    @inlinable func camelise(_ isSeparator: (String.UTF8View.Element) -> Bool) -> String {
        let u = utf8
        var s = u.startIndex
        let e = u.endIndex
        var result = String()
        var i = s
        while i < e {
            var j = u.index(after: i)
            let char = u[i]
            if isSeparator(char) {
                if let str = String(u[s..<i]) {
                    result += str
                    s = i
                }
                i = j
                guard i < e else { break }
                j = u.index(after: i)
                if let u = String(u[i..<j])?.unicodeScalars.first, u.isASCII {
                    let c = Int32(u.value)
                    if islower(c) != 0 {
                        let upper = UnicodeScalar(UInt8(toupper(c)))
                        result += String(Character(upper))
                        s = j
                    } else {
                        s = i
                    }
                } else {
                    s = i
                }
            }
            i = j
        }
        if let str = String(u[s..<e]) { result += str }
        return result
    }

    /// convert the receiver to camel case
    @inlinable var camelCase: String { return camelise { $0 == underscore } }

    /// convert a signal name with '-' to camel case
    @inlinable var camelSignal: String {
        return camelise { $0 == minus || $0 == underscore }.deCapitalised
    }

    /// convert a signal name component with '-' to camel case
    @inlinable var camelSignalComponent: String {
        return camelise { $0 == minus || $0 == underscore }.capitalised
    }

    /// Return the number of trailing asterisks to count, ignoring white space
    @inlinable var trailingAsteriskCountIgnoringWhitespace: Int { countTrailing(character: "*", in: self, ignoringWhiteSpace: true) }
}

public extension Substring {
    /// convert a substring with separators to camel case
    @inlinable func camelise(_ isSeparator: (String.UTF8View.Element) -> Bool) -> String {
        let u = utf8
        var s = u.startIndex
        let e = u.endIndex
        var result = String()
        var i = s
        while i < e {
            var j = u.index(after: i)
            let char = u[i]
            if isSeparator(char) {
                if let str = String(u[s..<i]) {
                    result += str
                    s = i
                }
                i = j
                guard i < e else { break }
                j = u.index(after: i)
                if let u = String(u[i..<j])?.unicodeScalars.first, u.isASCII {
                    let c = Int32(u.value)
                    if islower(c) != 0 {
                        let upper = UnicodeScalar(UInt8(toupper(c)))
                        result += String(Character(upper))
                        s = j
                    } else {
                        s = i
                    }
                } else {
                    s = i
                }
            }
            i = j
        }
        if let str = String(u[s..<e]) { result += str }
        return result
    }

    /// convert the receiver to camel case
    @inlinable var camelCase: String { return camelise { $0 == underscore } }
}

/// Count the number of specific trailing characters
/// - Parameters:
///   - character: The trailing character to match
///   - string: The String (or SubString) to examine
/// - Returns: The numbber of trailing characters matching the given character
@inlinable func countTrailing<S: StringProtocol>(character: Character, in string: S, ignoringWhiteSpace: Bool = false) -> Int {
    let c = string.last
    let isWhiteSpace = c?.isWhitespace ?? false
    guard c == character || ignoringWhiteSpace && isWhiteSpace else { return 0 }
    let k = ignoringWhiteSpace && isWhiteSpace ? 0 : 1
    let s = string.startIndex
    let e = string.index(before: string.endIndex)
    return k + countTrailing(character: character, in: string[s..<e], ignoringWhiteSpace: ignoringWhiteSpace)
}
