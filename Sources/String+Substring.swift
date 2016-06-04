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
}


