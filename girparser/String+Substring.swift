//
//  String+Substring.swift
//  Gtk3Swift
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
    /// return the string resulting from removing the given suffix
    public func stringByRemoving(suffix s: String) -> String? {
        let len = s.characters.count
        return hasSuffix(s) ? String(characters[startIndex..<index(endIndex, offsetBy: -len)]) : nil
    }
}


