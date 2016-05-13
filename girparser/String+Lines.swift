//
//  String+Lines.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 13/05/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif


extension String {
    /// split the string into an array of substrings
    func split(separator s: Character = "\n") -> [String] {
        return characters.split(separator: s).map { String($0) }
    }

    /// return the lines of the given string
    var lines: [String] { return split() }
}
