//
//  String+Lines.swift
//  gir2swift
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
    /// Split a string into substrings separated by the given character
    func split(separator s: Character = "\n") -> [String] {
        let u = String(s).utf16.first!
        let components = utf16.split(separator: u).map { String($0)! }
        return components
    }

    /// return the lines of the given string
    var lines: [String] { return split() }
}
