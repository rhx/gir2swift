//
//  gir+swift.swift
//  Gtk3Swift
//
//  Created by Rene Hexel on 2/04/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//

public extension GIR {
    /// code boiler plate
    public var boilerPlate: String {
        return "private func cast<S, T>(param: UnsafeMutablePointer<S>) -> UnsafeMutablePointer<T> {\n" +
        "    return UnsafeMutablePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast<S, T>(param: UnsafeMutablePointer<S>) -> UnsafePointer<T> {\n" +
        "    return UnsafePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast<S, T>(param: UnsafePointer<S>) -> UnsafePointer<T> {\n" +
        "    return UnsafePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast<T>(param: COpaquePointer) -> UnsafeMutablePointer<T> {\n" +
        "    return UnsafeMutablePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast<T>(param: COpaquePointer) -> UnsafePointer<T> {\n" +
        "    return UnsafePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast<S, T>(param: UnsafePointer<S>) -> UnsafeMutablePointer<T> {\n" +
        "    return UnsafeMutablePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast<T>(param: UnsafePointer<T>) -> COpaquePointer {\n" +
        "    return COpaquePointer(param)\n" +
        "}\n\n" +

        "private func cast<T>(param: UnsafeMutablePointer<T>) -> COpaquePointer {\n" +
        "    return COpaquePointer(param)\n" +
        "}\n\n" +

        "private extension gboolean {\n" +
        "    private init(_ b: Bool) { self = b ? gboolean(1) : gboolean(0) }\n" +
        "}\n\n" +

        "private func asStringArray(param: UnsafePointer<UnsafePointer<CChar>>) -> [String] {\n" +
        "    var ptr = param\n" +
        "    var rv = [String]()\n" +
        "    while ptr.memory != nil {\n" +
        "        if let s = String.fromCString(ptr.memory) {\n" +
        "            rv.append(s)\n" +
        "        }\n" +
        "        ptr = ptr.successor()\n" +
        "    }\n" +
        "    return rv\n" +
        "}\n\n" +

        "private func asStringArray<T>(param: UnsafePointer<UnsafePointer<CChar>>, release: (UnsafePointer<T> -> Void)) -> [String] {\n" +
        "    let rv = asStringArray(param)\n" +
        "    release(UnsafePointer<T>(param))\n" +
        "    return rv\n" +
        "}\n\n"
    }
}


/// Swift extension for arguments
public extension GIR.Argument {
    /// indicates whether the receiver is a known type
    public var isKnownType: Bool { return GIR.knownTypes[type.swift] != nil }

    /// indicates whether the receiver is a known class or record
    public var isKnownRecord: Bool { return GIR.knownRecords[type.swift] != nil }

    /// indicates whether the receiver is any known kind of pointer
    public var isAnyKindOfPointer: Bool {
        return ctype.isGPointer || ctype.isPointer || ctype.isCastablePointer || type.isSwiftPointer
    }

    /// indicates whether the receiver is an array of scalar values
    public var isScalarArray: Bool { return isArray && !isAnyKindOfPointer }

    /// return a non-clashing argument name
    public var nonClashingName: String {
        let sw = name.swift
        let nt = sw + (sw.isKnownType ? "_" : "")
        let nc = nt == ctype.innerCType ? nt + "_" : nt
        let ns = nc == type.innerCType  ? nc + "_" : nc
        return ns
    }

    /// return whether the receiver is an instance of the given record (class)
    public func isInstanceOf(_ record: GIR.Record?) -> Bool {
        if let r = record where r.node == type.withoutNameSpace {
            return true
        } else {
            return false
        }
    }
}


/// Swift extension for methods
public extension GIR.Method {
    public var isDesignatedConstructor: Bool {
        return name == "new"
    }

    /// is this a bare factory method that is not the default constructor
    public var isBareFactory: Bool {
        return args.isEmpty && !isDesignatedConstructor
    }

    /// return whether the method is a constructor of the given record
    public func isConstructorOf(_ record: GIR.Record?) -> Bool {
        return returns.isInstanceOf(record) && !(args.first?.isInstanceOf(record) ?? false)
    }

    /// return whether the method is a factory of the given record
    public func isFactoryOf(_ record: GIR.Record?) -> Bool {
        return !isDesignatedConstructor && isConstructorOf(record)
    }
}


/// GIR extension for Strings
extension String {
    /// indicates whether the receiver is a known type
    public var isKnownType: Bool { return GIR.knownTypes[self] != nil }
}


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
        t = s + "\n\(indentation)///\n\(indentation)/// **\(thing.name) is deprecated:**\n" + d
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
    return swiftCode(constant, "public let \(constant.name.swift) = \(constant.type.swift) /* \(constant.ctype) \(constant.value) */")
}

/// Magic error type for throwing
let errorType = "ErrorType"

/// Escaped version of the Error type
let errorTypeEscaped = errorType + "Enum"

/// underlying error type
let gerror = "GError"

/// Swift code type alias representation of an enum
public func typeAlias(_ e: GIR.Enumeration) -> String {
    let swift = e.name.swift
    let name = swift == errorType ? errorTypeEscaped : swift
    return swiftCode(e, "public typealias \(name) = \(e.type.swift)")
}

/// Swift code representation of an enum
public func swiftCode(_ e: GIR.Enumeration) -> String {
    let alias = typeAlias(e)
    let swift = e.name.swift
    let isErrorType = swift == errorType
    let name = isErrorType ? errorTypeEscaped : swift
    let ext = isErrorType ? ": \(errorType)" : ""
    let pub = isErrorType ? "" : "public "
    let code = alias + "\n\n\(pub)extension \(name)\(ext) {\n" + e.members.map(valueCode("    ")).joinWithSeparator("\n") + "\n}"
    return code
}

/// Swift code representation of an enum value
public func valueCode(_ indentation: String) -> GIR.Enumeration.Member -> String {
    return { (m: GIR.Enumeration.Member) -> String in
        swiftCode(m, indentation + "public static let \(m.name.swift) = \(m.ctype.swift) /* \(m.value) */", indentation: indentation)
    }
}


/// Swift protocol representation of a record/class as a wrapper of a pointer
public func recordProtocolCode(_ e: GIR.Record, parent: String, indentation: String = "    ") -> String {
    let p = (parent.isEmpty ? "" : ": \(parent)")
    let code = "public protocol \(e.node)Protocol\(p) {\n" + indentation +
        "var ptr: UnsafeMutablePointer<\(e.ctype.swift)> { get }\n" +
    "}\n\n"
    return code
}


/// Default implementation for record methods as protocol extension
public func recordProtocolExtensionCode(_ e: GIR.Record, indentation: String = "    ") -> String {
    let mcode = methodCode(indentation)(e)
    let methods = e.methods + e.functions.filter { $0.args.lazy.filter({ $0.isInstanceOf(e) }).first != nil }
    let code = "public extension \(e.node)Protocol {\n" +
        methods.map(mcode).joinWithSeparator("\n") +
    "}\n\n"
    return code
}


/// Swift code for methods (with a given indentation)
public func methodCode(_ indentation: String) -> GIR.Record -> GIR.Method -> String {
  return { (record: GIR.Record) -> GIR.Method-> String in
    let doubleIndent = indentation + indentation
    let call = callCode(doubleIndent, record)
    let returnDeclaration = returnDeclarationCode()
    let ret = returnCode(indentation)
      return { (method: GIR.Method) -> String in
        let name = method.name.isEmpty ? method.cname : method.name
        guard !method.varargs else {
            return "\n\(indentation)// *** \(name)() is not available because it has a varargs (...) parameter!\n\n"
        }
        let deprecated = method.deprecated != nil ? "@available(*, deprecated) " : ""
        let code = swiftCode(method, indentation + "\(deprecated)public func \(name.swift)(" +
            funcParam(method, record) + ")\(returnDeclaration(method)) {\n" +
                doubleIndent + call(method) +
                indentation  + ret(method)  +
        "}\n", indentation: indentation)
        return code
      }
   }
}


/// Swift code for convenience constructors
public func convenienceConstructorCode(_ typeName: String, indentation: String, convenience: String = "", factory: Bool = false) -> GIR.Record -> GIR.Method -> String {
    let isConv = !convenience.isEmpty
    let conv =  isConv ? "\(convenience) " : ""
    return { (record: GIR.Record) -> GIR.Method-> String in
        let doubleIndent = indentation + indentation
        let call = callCode(doubleIndent)
        let returnDeclaration = returnDeclarationCode((typeName: typeName, record: record, isConstructor: !factory))
        let ret = returnCode(indentation, (typeName: typeName, record: record, isConstructor: !factory, isConvenience: isConv))
        return { (method: GIR.Method) -> String in
            let name = method.name.isEmpty ? method.cname : method.name
            guard !method.varargs else {
                return "\n\(indentation)// *** \(name)() is not available because it has a varargs (...) parameter!\n\n"
            }
            let deprecated = method.deprecated != nil ? "@available(*, deprecated) " : ""
            let consPrefix = constructorPrefix(method)
            let prefix = consPrefix == method.args.first?.name.swift ? "" : (consPrefix + " ")
            let fact = factory ? "static func \(name.swift)(" : "\(conv)init(\(prefix)"
            let code = swiftCode(method, indentation + "\(deprecated)public \(fact)" +
                constructorParam(method) + ")\(returnDeclaration(method)) {\n" +
                    doubleIndent + call(method) +
                    indentation  + ret(method)  +
                "}\n", indentation: indentation)
            return code
        }
    }
}


/// Return code declaration for functions/methods/convenience constructors
public func returnDeclarationCode(_ tr: (typeName: String, record: GIR.Record, isConstructor: Bool)? = nil) -> GIR.Method -> String {
    return { method in
        let throwCode = method.throwsError ? " throws" : ""
        let rv = method.returns
        guard !(rv.isVoid || (tr != nil && tr!.isConstructor)) else { return throwCode }
        let returnType: String
        if rv.isInstanceOf(tr?.record)  {
            returnType = tr!.typeName
        } else {
            returnType = typeCastTuple(rv.ctype, rv.type.swift).swift
        }
        return throwCode + " -> \(returnType)"
    }
}


/// Return code for functions/methods/convenience constructors
public func returnCode(_ indentation: String, _ tr: (typeName: String, record: GIR.Record, isConstructor: Bool, isConvenience: Bool)? = nil) -> GIR.Method -> String {
    return { method in
        let rv = method.returns
        guard !rv.isVoid else { return "" }
        let isInstance = rv.isInstanceOf(tr?.record)
        let cast2swift = typeCastTuple(rv.ctype, rv.type.swift, forceCast: isInstance).toSwift
        guard isInstance else { return indentation + "return \(cast2swift)\n" + indentation }
        let cons = tr!.isConstructor ? "self.init" : "return \(tr!.typeName)"
        if tr!.isConvenience || !tr!.isConstructor {
            return indentation + "\(cons)(ptr: \(cast2swift))\n" + indentation
        } else {
            return indentation + "self.ptr = \(cast2swift)\n" + indentation
        }
    }
}


/// Swift code for calling the underlying function and assigning the raw return value
public func callCode(_ indentation: String, _ record: GIR.Record? = nil) -> GIR.Method -> String {
    let toSwift = convertArgumentToSwiftFor(record)
    return { method in
        let throwsError = method.throwsError
        let args = method.args // not .lazy
        let rv = method.returns
        let isVoid = rv.isVoid
        let code = ( throwsError ? "var error: UnsafeMutablePointer<\(gerror)> = nil\n" + indentation : "") +
        ( isVoid ? "" : "let rv = " ) +
        "\(method.cname.swift)(\(args.map(toSwift).joinWithSeparator(", "))" +
        ( throwsError ? (", &error)\n" + indentation + "guard error == nil else {\n" + indentation + indentation + "throw Error(ptr: error)\n" + indentation + "}\n") : ")\n" )
        return code
    }
}


/// Swift code for the parameters of a method or function
public func funcParam(_ method: GIR.Method, _ record: GIR.Record? = nil) -> String {
    return method.args.lazy.filter { !$0.instance && !$0.isInstanceOf(record) } .map(argumentCode).joinWithSeparator(", ")
}


/// Swift code for the parameters of a constructor
public func constructorParam(_ method: GIR.Method) -> String {
    return method.args.lazy.map(argumentCode).joinWithSeparator(", ")
}


/// Swift code for constructor prefix extracted from a method name
public func constructorPrefix(_ method: GIR.Method) -> String {
    let cname = method.cname
    let chars = cname.characters
    let components = chars.split("_").map { $0.map({ String($0) }).joinWithSeparator("") }
    guard let from = components.lazy.enumerate().filter({ $0.1 == "from" }).first else {
        let mn = method.name
        let name = mn.isEmpty ? cname : mn
        let unPrefixed: String
        if let prefix = (["new_", "new"].lazy.filter { name.hasPrefix($0) }.first) {
            let chars = name.characters
            let s = chars.startIndex.advancedBy(prefix.characters.count)
            let e = chars.endIndex
            unPrefixed = String(chars[s..<e])
        } else {
            unPrefixed = name
        }
        let shortened: String
        if let suffix = (["_new"].lazy.filter { unPrefixed.hasSuffix($0) }.first) {
            let chars = unPrefixed.characters
            let s = chars.startIndex
            let e = chars.endIndex.advancedBy(-suffix.characters.count)
            shortened = String(chars[s..<e])
        } else {
            shortened = unPrefixed
        }
        return shortened.swift
    }
    let f = components.startIndex + from.index + 1
    let e = components.endIndex
    let s = f < e ? f : f - 1
    let name = components[s..<e].joinWithSeparator("_")
    return name.swift
}


/// Swift code for methods
public func argumentCode(_ arg: GIR.Argument) -> String {
    let name = arg.nonClashingName
    let swname = arg.name.swift
    let prefixedname = name == swname ? name : (swname + " " + name)
    let ctype = arg.ctype
    let type = arg.type
    let array = arg.isScalarArray
    let swift = array ? type.swiftType : type.swift
    let isPtr  = ctype.isPointer
    let code = "\(array ? "inout " : "")\(prefixedname): \(array ? "[" : "")\(isPtr ? (arg.isKnownRecord ? swift + "Protocol" : ctype.swiftRepresentationOfCType) : swift)\(array ? "]" : "")"
    return code
}


/// Swift code for passing an argument to a free standing function
public func toSwift(_ arg: GIR.Argument) -> String {
    let types = typeCastTuple(arg.ctype, arg.type.swift, varName: arg.instance ? "ptr" : (arg.nonClashingName + (arg.isKnownRecord ? ".ptr" : "")))
    let param = types.toC.hasSuffix("ptr") ? "cast(\(types.toC))" : types.toC
    return param
}


/// Swift code for passing an argument to a method of a record / class
public func convertArgumentToSwiftFor(_ record: GIR.Record?) -> GIR.Argument -> String {
    return { arg in
        let name = arg.nonClashingName
        guard !arg.isScalarArray else { return "&" + name }
        let types = typeCastTuple(arg.ctype, arg.type.swift, varName: arg.instance || arg.isInstanceOf(record) ? "ptr" : (name + (arg.isKnownRecord ? ".ptr" : "")))
        let param = types.toC.hasSuffix("ptr") ? "cast(\(types.toC))" : types.toC
        return param
    }
}




/// Swift struct representation of a record/class as a wrapper of a pointer
public func recordStructCode(_ e: GIR.Record, indentation: String = "    ") -> String {
    let structType = "\(e.node)Ref"
    let ccode = convenienceConstructorCode(structType, indentation: indentation)(e)
    let fcode = convenienceConstructorCode(structType, indentation: indentation, factory: true)(e)
    let constructors = e.constructors.filter { $0.isConstructorOf(e) && !$0.isBareFactory }
    let factories = (e.constructors + e.methods + e.functions).filter { $0.isFactoryOf(e) }
    let code = "public struct \(structType): \(e.node)Protocol {\n" + indentation +
        "public let ptr: UnsafeMutablePointer<\(e.ctype.swift)>\n" +
    "}\n\n" +
    "public extension \(structType) {\n" + indentation +
        "public init<T>(cPointer: UnsafeMutablePointer<T>) {\n" + indentation + indentation +
            "ptr = UnsafeMutablePointer<\(e.ctype.swift)>(cPointer)\n" + indentation +
        "}\n\n" + indentation +
        "public init<T>(constPointer: UnsafePointer<T>) {\n" + indentation + indentation +
            "ptr = UnsafeMutablePointer<\(e.ctype.swift)>(constPointer)\n" + indentation +
        "}\n\n" + indentation +
        "public init(opaquePointer: COpaquePointer) {\n" + indentation + indentation +
            "ptr = UnsafeMutablePointer<\(e.ctype.swift)>(opaquePointer)\n" + indentation +
        "}\n\n" + indentation +
        constructors.map(ccode).joinWithSeparator("\n") +
        factories.map(fcode).joinWithSeparator("\n") +
    "}\n\n"

    return code
}


/// Swift struct representation of a record/class as a wrapper of a pointer
public func recordClassCode(_ e: GIR.Record, parent: String, indentation: String = "    ") -> String {
    let classType = e.name.swift
    let ccode = convenienceConstructorCode(classType, indentation: indentation, convenience: "convenience")(e)
    let fcode = convenienceConstructorCode(classType, indentation: indentation, factory: true)(e)
    let constructors = e.constructors.filter { $0.isConstructorOf(e) && !$0.isBareFactory }
    let factories = (e.constructors + e.methods + e.functions).filter { $0.isFactoryOf(e) }
    let p = parent.isEmpty ? "" : "\(parent), "
    let code = "public class \(classType): \(p)\(e.node)Protocol {\n" + indentation +
        "public let ptr: UnsafeMutablePointer<\(e.ctype.swift)>\n\n" + indentation +
        "public init(ptr: UnsafeMutablePointer<\(e.ctype.swift)>) {\n" + indentation + indentation +
            "self.ptr = ptr\n" + indentation +
        "}\n\n" + indentation +
        "deinit {\n" + indentation + indentation +
            "g_free(UnsafeMutablePointer(ptr))\n" + indentation +
        "}\n\n" +
    "}\n\n" +
        "public extension \(classType) {\n" + indentation +
        "public convenience init<T>(cPointer: UnsafeMutablePointer<T>) {\n" + indentation + indentation +
            "self.init(ptr: UnsafeMutablePointer<\(e.ctype.swift)>(cPointer))\n" + indentation +
        "}\n\n" + indentation +
//        "public convenience init<T>(cPointer: UnsafePointer<T>) {\n" + indentation + indentation +
//        "    self.init(ptr: UnsafeMutablePointer<\(e.ctype.swift)>(cPointer))\n" + indentation +
//        "}\n\n" + indentation +
        "public convenience init(opaquePointer: COpaquePointer) {\n" + indentation + indentation +
            "self.init(ptr: UnsafeMutablePointer<\(e.ctype.swift)>(opaquePointer))\n" + indentation +
        "}\n\n" + indentation +
        constructors.map(ccode).joinWithSeparator("\n") +
        factories.map(fcode).joinWithSeparator("\n") +
    "}\n\n"

    return code
}




/// Swift code representation of a record
public func swiftCode(_ e: GIR.Record) -> String {
    let errorProtocol = e.ctype == gerror ? errorType : ""
    let p = recordProtocolCode(e, parent: errorProtocol)
    let s = recordStructCode(e)
    let c = recordClassCode(e, parent: "")
    let e = recordProtocolExtensionCode(e)
    let code = p + s + c + e
    return code
}

