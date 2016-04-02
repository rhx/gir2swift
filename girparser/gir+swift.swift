//
//  gir+swift.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 2/04/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//

/// Swift representation of comments
public func commentCode(thing: GIR.Thing, indentation: String = "") -> String {
    return thing.comment.isEmpty ? "" : thing.comment.characters.reduce(indentation + "/// ") {
        $0 + ($1 == "\n" ? "\n" + indentation + "/// " : String($1))
    }
}

/// Swift representation of deprecation
public func deprecatedCode(thing: GIR.Thing, indentation: String) -> String? {
    return thing.deprecated.map {
        $0.isEmpty ? "" : $0.characters.reduce(indentation + "/// ") {
            $0 + ($1 == "\n" ? "\n" + indentation + "/// " : String($1))
        }
    }
}

/// Swift code representation with code following the comments
public func swiftCode(thing: GIR.Thing, _ postfix: String = "", indentation: String = "") -> String {
    let s = commentCode(thing, indentation: indentation)
    let t: String
    if let d = deprecatedCode(thing, indentation: indentation) {
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

/// Swift code type alias representation of an enum
public func typeAlias(e: GIR.Enumeration) -> String {
    return swiftCode(e, "public typealias \(e.name) = \(e.type)")
}

/// Swift code representation of an enum
public func swiftCode(e: GIR.Enumeration) -> String {
    let alias = typeAlias(e)
    let code = alias + "\n\npublic extension \(e.name) {\n" + e.members.map(valueCode("    ")).joinWithSeparator("\n") + "\n}"
    return code
}

/// Swift code representation of an enum value
public func valueCode(indentation: String) -> GIR.Enumeration.Member -> String {
    return { (m: GIR.Enumeration.Member) -> String in
        swiftCode(m, indentation + "public static let \(m.name) = \(m.ctype) /* \(m.value) */", indentation: indentation)
    }
}
