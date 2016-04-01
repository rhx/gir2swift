//
//  gir+swift.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 2/04/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//

/// Swift representation of comments
public func commentCode(thing: GIR.Thing) -> String {
    return thing.comment.isEmpty ? "" : thing.comment.characters.reduce("/// ") {
        $0 + ($1 == "\n" ? "\n/// " : String($1))
    }
}

/// Swift representation of deprecation
public func deprecatedCode(thing: GIR.Thing) -> String? {
    return thing.deprecated.map {
        $0.isEmpty ? "" : $0.characters.reduce("/// ") {
            $0 + ($1 == "\n" ? "\n/// " : String($1))
        }
    }
}

/// Swift code representation with code following the comments
public func swiftCode(thing: GIR.Thing, _ postfix: String = "") -> String {
    let s = commentCode(thing)
    let t: String
    if let d = deprecatedCode(thing) {
        t = s + d
    } else {
        t = s
    }
    return t + (s.isEmpty ? "" : "\n") + postfix
}

/// Swift code representation of a type alias
public func swiftCode(alias: GIR.Alias) -> String {
    return swiftCode(alias, "public typealias \(alias.name) = \(alias.type)")
}

/// Swift code representation of a constant
public func swiftCode(constant: GIR.Constant) -> String {
    return swiftCode(constant, "public let \(constant.name) = \(constant.type) /* \(constant.value) */")
}
