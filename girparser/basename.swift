//
//  basename.swift
//  posix
//
//  Created by Rene Hexel on 3/08/2014.
//  Copyright (c) 2014, 2016 Rene Hexel. All rights reserved.
//
#if os(Linux)
    import GLibc
#else
    import Darwin
#endif


/// return the base name of a string
extension String {
    var baseName: String {
        return String.fromCString(basename(cstring(self)))!
    }
}
