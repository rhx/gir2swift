//
//  basename.swift
//  posix
//
//  Created by Rene Hexel on 3/08/2014.
//  Copyright (c) 2014, 2016, 2019 Rene Hexel. All rights reserved.
//
#if os(Linux)
    import Glibc

    /// just a slash
    private let slash = "/".utf8.first!

    /// return the base name of a string
    public extension String {
        var baseName: String {
            let u = utf8
            let s = u.startIndex
            let e = u.endIndex
            var i = e
            while i != s {
                let j = u.index(before: i)
                if u[j] == slash {
                    return String(Substring(u[i..<e]))
                }
                i = j
            }
            return self
        }
    }
#else
    import Darwin


    /// return the base name of a string
    public extension String {
        var baseName: String {
            return String(cString: basename(cstring(self)))
        }
    }
#endif
