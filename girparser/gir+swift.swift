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
    return swiftCode(alias, "public typealias \(alias.name.swift) = \(alias.type.swift)")
}

/// Swift code representation of a constant
public func swiftCode(constant: GIR.Constant) -> String {
    return swiftCode(constant, "public let \(constant.name.swift) = \(constant.type.swift) /* \(constant.value) */")
}

/// Magic error type for throwing
let errorType = "ErrorType"

/// underlying error number
var gerrorType = "GErrorType"

/// underlying error type
let gerror = "GError"

/// Swift code type alias representation of an enum
public func typeAlias(e: GIR.Enumeration) -> String {
    let name = e.name.swift
    guard name != errorType else {
        return swiftCode(e, "public protocol \(e.type.swift): \(errorType) {}")
    }
    return swiftCode(e, "public typealias \(e.name.swift) = \(e.type.swift)")
}

/// Swift code representation of an enum
public func swiftCode(e: GIR.Enumeration) -> String {
    let alias = typeAlias(e)
    let swift = e.name.swift
    let name = swift == errorType ? e.type.swift : swift
    let code = alias + "\n\npublic extension \(name) {\n" + e.members.map(valueCode("    ")).joinWithSeparator("\n") + "\n}"
    return code
}

/// Swift code representation of an enum value
public func valueCode(indentation: String) -> GIR.Enumeration.Member -> String {
    return { (m: GIR.Enumeration.Member) -> String in
        swiftCode(m, indentation + "public static let \(m.name.swift) = \(m.ctype.swift) /* \(m.value) */", indentation: indentation)
    }
}


/// Swift protocol representation of a record/class as a wrapper of a pointer
public func recordProtocolCode(e: GIR.Record, parent: String, indentation: String = "    ") -> String {
    let p = (parent.isEmpty ? "" : ": \(parent)")
    let code = "public protocol \(e.node)Protocol\(p) {\n" + indentation +
        "var ptr: UnsafeMutablePointer<\(e.ctype.swift)> { get }\n" +
    "}\n\n"
    return code
}


/// Default implementation for record methods as protocol extension
public func recordProtocolExtensionCode(e: GIR.Record, indentation: String = "    ") -> String {
    let mcode = methodCode(indentation)(e)
    let code = "public extension \(e.node)Protocol {\n" +
        e.methods.lazy.map(mcode).joinWithSeparator("\n") +
    "}\n\n"
    return code
}


/// Swift code for methods (with a given indentation)
public func methodCode(_ indentation: String) -> GIR.Record -> GIR.Method -> String {
    return { (record: GIR.Record) -> GIR.Method-> String in { (method: GIR.Method) -> String in
        let args = method.args.lazy
        let isVoid = method.returns.isVoid
        let returnType = isVoid ? "" : " -> \(method.returns.ctype == "" ? method.returns.type.swift : toSwift(method.returns.ctype))"
        let throwsError = method.throwsError
        let throwCode = throwsError ? "throws " : ""
//        let n = args.count
//        print("\(method.name): \(n) arguments:")
//        method.args.forEach {
//            print("\($0.name)[instance=\($0.instance)]: \($0.type) = '\($0.ctype)'")
//        }
        return indentation + "public func \(method.name.swift)(" +
            args.filter { !$0.instance } .map(argumentCode).joinWithSeparator(", ") +
        ")\(returnType) \(throwCode){\n" + indentation + indentation +
            ( throwsError ? "let error: UnsafeMutablePointer<\(gerror)> = nil\n" + indentation + indentation : "") +
            ( isVoid ? "" : "let rv = " ) +
        "\(method.cname.swift)(\(args.map(toSwift).joinWithSeparator(", "))" +
            ( throwsError ? ", &error" : "" ) +
            ")\n" + indentation +
            ( throwsError ? indentation + "guard error == nil else {\n" + indentation + indentation + indentation + "throw GError(ptr: error)\n" + indentation + indentation + "}\n" + indentation : "" ) +
            ( isVoid ? "" : indentation + "return rv\n" + indentation ) +
        "}\n"
        }}
}


/// Swift code for methods
public func argumentCode(arg: GIR.Argument) -> String {
    return "\(arg.name.swift): \(arg.ctype.isCPointer ? arg.ctype.swiftRepresentationOfCType : arg.type.swift)"
}


/// Swift code for argument
public func toSwift(_ arg: GIR.Argument) -> String {
    return arg.instance ? "ptr" : arg.name.swift.cast_as_c(arg.type.swift)
}




/// Swift struct representation of a record/class as a wrapper of a pointer
public func recordStructCode(e: GIR.Record, indentation: String = "    ") -> String {
    let code = "public struct \(e.node)Ref: \(e.node)Protocol {\n" + indentation +
        "public let ptr: UnsafeMutablePointer<\(e.ctype.swift)>\n" +
    "}\n\n" +
    "public extension \(e.node)Ref {\n" + indentation +
        "public init<T>(cPointer: UnsafeMutablePointer<T>) {\n" + indentation + indentation +
            "ptr = UnsafeMutablePointer<\(e.ctype.swift)>(cPointer)\n" + indentation +
        "}\n\n" + indentation +
        "public init<T>(constPointer: UnsafePointer<T>) {\n" + indentation + indentation +
            "ptr = UnsafeMutablePointer<\(e.ctype.swift)>(constPointer)\n" + indentation +
        "}\n\n" + indentation +
        "public init(opaquePointer: COpaquePointer) {\n" + indentation + indentation +
            "ptr = UnsafeMutablePointer<\(e.ctype.swift)>(opaquePointer)\n" + indentation +
        "}\n\n" +
    "}\n\n"

    return code
}


/// Swift struct representation of a record/class as a wrapper of a pointer
public func recordClassCode(e: GIR.Record, parent: String, indentation: String = "    ") -> String {
    let p = parent.isEmpty ? "" : "\(parent), "
    let code = "public class \(e.name.swift): \(p)\(e.node)Protocol {\n" + indentation +
        "public let ptr: UnsafeMutablePointer<\(e.ctype.swift)>\n\n" + indentation +
        "public init(ptr: UnsafeMutablePointer<\(e.ctype.swift)>) {\n" + indentation + indentation +
            "self.ptr = ptr\n" + indentation +
        "}\n\n" + indentation +
        "deinit {\n" + indentation + indentation +
            "g_free(UnsafeMutablePointer(ptr))\n" + indentation +
        "}\n\n" +
    "}\n\n" +
        "public extension \(e.name) {\n" + indentation +
        "public convenience init<T>(cPointer: UnsafeMutablePointer<T>) {\n" + indentation + indentation +
            "self.init(ptr: UnsafeMutablePointer<\(e.ctype.swift)>(cPointer))\n" + indentation +
        "}\n\n" + indentation +
//        "public convenience init<T>(cPointer: UnsafePointer<T>) {\n" + indentation + indentation +
//        "    self.init(ptr: UnsafeMutablePointer<\(e.ctype.swift)>(cPointer))\n" + indentation +
//        "}\n\n" + indentation +
        "public convenience init(opaquePointer: COpaquePointer) {\n" + indentation + indentation +
            "self.init(ptr: UnsafeMutablePointer<\(e.ctype.swift)>(opaquePointer))\n" + indentation +
        "}\n\n" +
    "}\n\n"

    return code
}




/// Swift code representation of a record
public func swiftCode(e: GIR.Record) -> String {
    let p = recordProtocolCode(e, parent: "")
    let s = recordStructCode(e)
    let c = recordClassCode(e, parent: "")
    let e = recordProtocolExtensionCode(e)
    let code = p + s + c + e
    return code
}

