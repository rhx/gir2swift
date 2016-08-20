//
//  basename.swift
//  posix
//
//  Created by Rene Hexel on 3/08/2014.
//  Copyright (c) 2014, 2016 Rene Hexel. All rights reserved.
//
#if os(Linux)
    import Glibc

    /// just a slash
    private let slash = "/".utf16.first!

    /// return the base name of a string
    extension String {
        var baseName: String {
            let u = utf16
            let s = u.startIndex
            let e = u.endIndex
            var i = e
            while i != s {
                let j = u.index(before: i)
                if u[j] == slash { return String(describing: u[i..<e]) }
                i = j
            }
            return self
        }
    }
#else
    import Darwin


    /// return the base name of a string
    extension String {
        var baseName: String {
            return String(cString: basename(cstring(self)))
        }
    }
#endif
