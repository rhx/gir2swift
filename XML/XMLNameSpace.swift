//
//  XMLNameSpace.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 25/03/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

///
/// XML Name space representation
///
public struct XMLNameSpace {
    let prefix: String          ///< xml element prefix
    let ns: String              ///< namespace URI
}
