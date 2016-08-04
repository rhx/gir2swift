//
//  String+Substring.swift
//  gir2swift
//
//  Created by Rene Hexel on 25/04/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
//
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/// UTF16 for underscore
private let underscore = "_".utf16.first!

/// UTF16 for minus
private let minus = "-".utf16.first!

extension String {
    /// return the unprefixed version of the string
    /// (e.g. type without namespace)
    public var unprefixed: String {
        guard let suffix = split(separator: ".").last else { return self }
        return suffix
    }

    /// return a prefixed version of the string
    public func prefixed(with prefix: String) -> String {
        guard !prefix.isEmpty else { return self }
        return prefix + "." + self
    }

    /// return the string resulting from removing the given suffix
    public func stringByRemoving(suffix s: String) -> String? {
        let len = s.characters.count
        return hasSuffix(s) ? String(characters[startIndex..<index(endIndex, offsetBy: -len)]) : nil
    }

    /// return the string resulting from removing the same number of
    /// characters as the given substring.  This will crash if the
    /// receiver is not long enough to have the corresponding number of
    /// characters removed
    public func stringByRemovingAnEquivalentNumberOfCharactersAs(suffix s: String) -> String {
        let len = s.characters.count
        return String(characters[startIndex..<index(endIndex, offsetBy: -len)])
    }

    /// return the substring after the first occurrence of the given character
    public func afterFirst(separator s: Character = "_") -> String? {
        let components = split(separator: s)
        guard components.count > 1 else { return nil }
        return components[components.index(after: components.startIndex)..<components.endIndex].joined(separator: String(s))
    }

    /// return the capidalised name of the receiver
    public var capitalised: String {
        guard let u = unicodeScalars.first, u.isASCII else { return self }
        let c = Int32(u.value)
        guard islower(c) != 0 else { return self }
        let upper = UInt16(toupper(c))
        let utf = utf16
        let tail = utf[utf.index(after: utf.startIndex)..<utf.endIndex]
        return String(Character(UnicodeScalar(upper)))+String(tail)
    }

    /// return the de-capidalised (lower-case first character) name of the receiver
    public var deCapitalised: String {
        guard let u = unicodeScalars.first, u.isASCII else { return self }
        let c = Int32(u.value)
        guard isupper(c) != 0 else { return self }
        let lower = UInt16(tolower(c))
        let utf = utf16
        let tail = utf[utf.index(after: utf.startIndex)..<utf.endIndex]
        return String(Character(UnicodeScalar(lower)))+String(tail)
    }

    /// convert a string with separators to camel case
    func camelise(_ isSeparator: (UInt16) -> Bool) -> String {
        let u = self.utf16
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
                        let upper = Character(UnicodeScalar(UInt32(toupper(c))))
                        result += String(upper)
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
    public var camelCase: String { return camelise { $0 == underscore } }

    /// convert a signal name with '-' to camel case
    public var camelSignal: String {
        return camelise { $0 == minus || $0 == underscore }.deCapitalised
    }
}
