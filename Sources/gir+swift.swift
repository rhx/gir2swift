//
//  gir+swift.swift
//  gir2swift
//
//  Created by Rene Hexel on 2/04/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif


public extension GIR {
    /// code boiler plate
    var boilerPlate: String {
        return "private func cast<S, T>(_ param: UnsafeMutablePointer<S>?) -> UnsafeMutablePointer<T>! {\n" +
        "    return UnsafeMutablePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast<S, T>(_ param: UnsafeMutablePointer<S>?) -> UnsafePointer<T>! {\n" +
        "    return UnsafePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast<S, T>(_ param: UnsafePointer<S>?) -> UnsafePointer<T>! {\n" +
        "    return UnsafePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast<T>(_ param: OpaquePointer?) -> UnsafeMutablePointer<T>! {\n" +
        "    return UnsafeMutablePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast<T>(_ param: OpaquePointer?) -> UnsafePointer<T>! {\n" +
        "    return UnsafePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast<S, T>(_ param: UnsafePointer<S>?) -> UnsafeMutablePointer<T>! {\n" +
        "    return UnsafeMutablePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast<T>(_ param: UnsafePointer<T>?) -> OpaquePointer! {\n" +
        "    return OpaquePointer(param)\n" +
        "}\n\n" +

        "private func cast<T>(_ param: UnsafeMutablePointer<T>?) -> OpaquePointer! {\n" +
        "    return OpaquePointer(param)\n" +
        "}\n\n" +

        "private extension gboolean {\n" +
        "    private init(_ b: Bool) { self = b ? gboolean(1) : gboolean(0) }\n" +
        "}\n\n" +

        "private func asStringArray(_ param: UnsafePointer<UnsafePointer<CChar>?>) -> [String] {\n" +
        "    var ptr = param\n" +
        "    var rv = [String]()\n" +
        "    while ptr.pointee != nil {\n" +
        "        rv.append(String(cString: ptr.pointee!))\n" +
        "        ptr = ptr.successor()\n" +
        "    }\n" +
        "    return rv\n" +
        "}\n\n" +

        "private func asStringArray<T>(_ param: UnsafePointer<UnsafePointer<CChar>?>, release: ((UnsafePointer<T>?) -> Void)) -> [String] {\n" +
        "    let rv = asStringArray(param)\n" +
        "    release(UnsafePointer<T>(param))\n" +
        "    return rv\n" +
        "}\n\n"
    }
}


/// Swift extension for arguments
public extension GIR.Argument {
    //// return the known type of the argument (nil if not known)
    public var knownType: GIR.Datatype? { return GIR.KnownTypes[type.swift] }

    //// return the known class/record of the argument (nil if not known)
    public var knownRecord: GIR.Record? { return GIR.KnownRecords[type.swift] }

    /// indicates whether the receiver is a known type
    public var isKnownType: Bool { return knownType != nil }

    /// indicates whether the receiver is a known class or record
    public var isKnownRecord: Bool { return knownRecord != nil }

    /// indicates whether the receiver is any known kind of pointer
    public var isAnyKindOfPointer: Bool {
        return ctype.isGPointer || ctype.isPointer || ctype.isCastablePointer || type.isSwiftPointer || type.hasSuffix("Func")
    }

    /// indicates whether the receiver is an array of scalar values
    public var isScalarArray: Bool { return isArray && !isAnyKindOfPointer }

    /// return a non-clashing argument name
    public var nonClashingName: String {
        let sw = name.swift
        let nt = sw + (sw.isKnownType ? "_" : "")
        let ct = ctype.innerCType.swiftType // swift name for C type
        let st = ctype.innerCType.swift     // corresponding Swift type
        let nc = nt == ct ? nt + "_" : nt
        let ns = nc == st ? nc + "_" : nc
        let na = ns == type.swift  ? ns + "_" : ns
        return na
    }

    /// return the, potentially prefixed argument name to use in a method declaration
    public var prefixedArgumentName: String {
        let name = nonClashingName
        let swname = name.swift
        let prefixedname = name == swname ? name : (swname + " " + name)
        return prefixedname
    }

    /// return the swift (known) type of the receiver
    public var argumentType: String {
        let ct = ctype
        let t = type == "" ? ct : type
        let array = isScalarArray
        let swift = array ? t.swiftType : t.swift
        let isPtr  = ct.isPointer
        let record = knownRecord
        let code = "\(array ? "inout [" : "")\(isPtr ? (record.map { $0.protocolName } ?? ct.swiftRepresentationOfCType) : swift)\(array ? "]" : "")"
        return code
    }

    /// return whether the receiver is an instance of the given record (class)
    public func isInstanceOf(_ record: GIR.Record?) -> Bool {
        if let r = record where r.name == type.withoutNameSpace {
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

/// a pair of getters and setters (both cannot be nil at the same time)
public struct GetterSetterPair {
    let getter: GIR.Method
    let setter: GIR.Method?
}

/// constant for "i" and "_" as a code unit
private let iU = "i".utf16.first
private let _U = "_".utf16.first!

extension GetterSetterPair {
    /// name of the underlying property for a getter / setter pair
    var name: String {
        let n = getter.name.utf16 ?? setter!.name.utf16
        let o = n.first == iU ? 0 : 4;  // no offset for "is_..."

        // convert the remainder to camel case
        var s = n.index(n.startIndex, offsetBy: o)
        let e = n.endIndex
        var name = String()
        var i = s
        while i < e {
            var j = n.index(after: i)
            if n[i] == _U {
                if let str = String(n[s..<i]) {
                    name += str
                    s = i
                }
                i = j
                guard i < e else { break }
                j = n.index(after: i)
                if let u = String(n[i..<j])?.unicodeScalars.first where u.isASCII {
                    let c = Int32(u.value)
                    if islower(c) != 0 {
                        let upper = Character(UnicodeScalar(UInt32(toupper(c))))
                        name += String(upper)
                        s = j
                    } else {
                        s = i
                    }
                } else {
                    s = i
                }
            }
            i = j
        }
        if let str = String(n[s..<e]) { name += str }
        return name
    }
}

/// return setter/getter pairs from a list of methods
public func getterSetterPairs(for allMethods: [GIR.Method]) -> [GetterSetterPair] {
    let gettersAndSetters = allMethods.filter{ $0.isGetter || $0.isSetter }.sorted {
        let u = $0.name.utf16
        let v = $1.name.utf16
        let o = u.first == iU ? 0 : 4;  // no offset for "is_..."
        let p = v.first == iU ? 0 : 4;
        let a = u[u.index(u.startIndex, offsetBy: o)..<u.endIndex]
        let b = v[v.index(v.startIndex, offsetBy: p)..<v.endIndex]
        return String(a) <= String(b)
    }
    var pairs = Array<GetterSetterPair>()
    pairs.reserveCapacity(gettersAndSetters.count)
    var i = gettersAndSetters.makeIterator()
    var b = i.next()
    while let a = b {
        b = i.next()
        if a.isGetter {
            guard let s = b where s.isSetterFor(getter: a.name) else { pairs.append(GetterSetterPair(getter: a, setter: nil)) ; continue }
            pairs.append(GetterSetterPair(getter: a, setter: s))
        } else {    // isSetter
            guard let g = b where g.isGetterFor(setter: a.name) else { continue }
            pairs.append(GetterSetterPair(getter: g, setter: a))
        }
        b = i.next()
    }
    return pairs
}

/// Swift extension for records
public extension GIR.Record {
    /// swift node name for this record
    public var swift: String { return name.swift }

    /// swift protocol name for this record
    public var protocolName: String { return swift + "Protocol" }

    /// swift struct name for this record
    public var structName: String { return swift + "Ref" }

    /// swift class name for this record
    public var className: String { return swift }
}


/// GIR extension for Strings
extension String {
    /// indicates whether the receiver is a known type
    public var isKnownType: Bool { return GIR.KnownTypes[self] != nil }
}


/// Swift representation of comments
public func commentCode(_ thing: GIR.Thing, indentation: String = "") -> String {
    let comment = thing.comment
    guard !comment.isEmpty else { return comment }
    let prefix = indentation + "/// "
    return comment.characters.reduce(prefix) {
        $0 + ($1 == "\n" ? "\n" + prefix : String($1))
    }
}

/// Swift representation of deprecation
public func deprecatedCode(_ thing: GIR.Thing, indentation: String) -> String? {
    return thing.deprecated.map { (s: String) -> String in
        let prefix = indentation + "/// "
        return s.isEmpty ? "" : s.characters.reduce(prefix) {
            $0 + ($1 == "\n" ? "\n" + prefix : String($1))
        }
    }
}

/// Swift code representation with code following the comments
public func swiftCode(_ thing: GIR.Thing, _ postfix: String = "", indentation: String = "") -> String {
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
    let type = constant.type.swift
    let name = constant.name.swift
    guard !GIR.VerbatimConstants.contains(name) else {
        return swiftCode(constant, "public let \(name): \(constant.ctype.swift) = \(constant.value) /* \(type) */")
    }
    return swiftCode(constant, "public let \(name) = \(type) /* \(constant.ctype) \(constant.value) */")
}

/// Magic error type for throwing
let errorProtocol = "ErrorProtocol"

/// error type enum
let errorType = "ErrorType"

/// underlying error type
let gerror = "GError"

/// Swift code type alias representation of an enum
public func typeAlias(_ e: GIR.Enumeration) -> String {
    return swiftCode(e, "public typealias \(e.name.swift) = \(e.type.swift)")
}

/// Swift code representation of an enum
public func swiftCode(_ e: GIR.Enumeration) -> String {
    let alias = typeAlias(e)
    let name = e.name
    let swift = name.swift
    let isErrorType = name == errorType || swift == errorType
    let ext = isErrorType ? ": \(errorProtocol)" : ""
    let pub = isErrorType ? "" : "public "
    let code = alias + "\n\n\(pub)extension \(name)\(ext) {\n" + e.members.map(valueCode("    ")).joined(separator: "\n") + "\n}"
    return code
}

/// Swift code representation of an enum value
public func valueCode(_ indentation: String) -> (GIR.Enumeration.Member) -> String {
    return { (m: GIR.Enumeration.Member) -> String in
        swiftCode(m, indentation + "public static let \(m.name.swift) = \(m.ctype.swift) /* \(m.value) */", indentation: indentation)
    }
}


/// Swift protocol representation of a record/class as a wrapper of a pointer
public func recordProtocolCode(_ e: GIR.Record, parent: String, indentation: String = "    ") -> String {
    let p = (parent.isEmpty ? "" : ": \(parent)")
    let code = "public protocol \(e.protocolName)\(p) {\n" + indentation +
        "var ptr: UnsafeMutablePointer<\(e.ctype.swift)> { get }\n" +
    "}\n\n"
    return code
}


/// Default implementation for record methods as protocol extension
public func recordProtocolExtensionCode(_ e: GIR.Record, indentation: String = "    ") -> String {
    let mcode = methodCode(indentation, record: e)
    let vcode = computedPropertyCode(indentation, record: e)
    let methods = e.methods + e.functions.filter { $0.args.lazy.filter({ $0.isInstanceOf(e) }).first != nil }
    let gsPairs = getterSetterPairs(for: methods)
    let code = "public extension \(e.protocolName) {\n" +
        methods.map(mcode).joined(separator: "\n") +
        gsPairs.map(vcode).joined(separator: "\n") +
    "}\n\n"
    return code
}


/// Default implementation for functions
public func functionCode(_ f: GIR.Function, indentation: String = "    ") -> String {
    let mcode = methodCode(indentation)
    let code = mcode(f) + "\n\n"
    return code
}


/// Swift code for methods (with a given indentation)
public func methodCode(_ indentation: String, record: GIR.Record? = nil) -> (GIR.Method) -> String {
    let doubleIndent = indentation + indentation
    let call = callCode(doubleIndent, record)
    let returnDeclaration = returnDeclarationCode()
    let ret = returnCode(indentation)
    return { (method: GIR.Method) -> String in
        let name = method.name.isEmpty ? method.cname : method.name
        guard !GIR.Blacklist.contains(name) else {
            return "\n\(indentation)// *** \(name)() causes a syntax error and is therefore not available!\n\n"
        }
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


/// Swift code for computed properties
public func computedPropertyCode(_ indentation: String, record: GIR.Record) -> (GetterSetterPair) -> String {
    let doubleIndent = indentation + indentation
    let gcall = callCode(doubleIndent, record)
    let scall = callSetter(doubleIndent, record)
    let ret = returnCode(doubleIndent)
    return { (pair: GetterSetterPair) -> String in
        let name = pair.name
        let getter = pair.getter
        let type: String
        if let rt = returnTypeCode()(getter) {
            type = rt
        } else {
            guard let args = pair.setter?.args.filter({ !$0.isInstanceOf(record) }),
                        at = args.first where args.count == 1 else {
                return indentation + "// var \(name) is unavailable because it does not have a valid getter or setter\n"
            }
            type = at.argumentType
        }
        let varDecl = indentation + "public var \(name): \(type) {\n"
        let deprecated = getter.deprecated != nil ? "@available(*, deprecated) " : ""
        let getterCode = swiftCode(getter, doubleIndent + "\(deprecated)get {\n" +
            doubleIndent + indentation + gcall(getter) +
            indentation  + ret(getter)  +
            "}\n", indentation: doubleIndent)
        let setterCode: String
        if let setter = pair.setter {
            let deprecated = setter.deprecated != nil ? "@available(*, deprecated) " : ""
            setterCode = swiftCode(setter, doubleIndent + "\(deprecated)set {\n" +
                doubleIndent + indentation + scall(setter) +
                doubleIndent + "}\n", indentation: doubleIndent)
        } else {
            setterCode = ""
        }
        let varEnd = indentation + "}\n"
        return varDecl + getterCode + setterCode + varEnd
    }
}




/// Swift code for convenience constructors
public func convenienceConstructorCode(_ typeName: String, indentation: String, convenience: String = "", factory: Bool = false) -> (GIR.Record) -> (GIR.Method) -> String {
    let isConv = !convenience.isEmpty
    let conv =  isConv ? "\(convenience) " : ""
    return { (record: GIR.Record) -> (GIR.Method)-> String in
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


/// Return the return type of a method, 
public func returnTypeCode(_ tr: (typeName: String, record: GIR.Record, isConstructor: Bool)? = nil) -> (GIR.Method) -> String? {
    return { method in
        let rv = method.returns
        guard !(rv.isVoid || (tr != nil && tr!.isConstructor)) else { return nil }
        let returnType: String
        if rv.isInstanceOf(tr?.record)  {
            returnType = tr!.typeName + "!"
        } else {
            returnType = typeCastTuple(rv.ctype, rv.type.swift).swift + (rv.isAnyKindOfPointer ? "!" : "")
        }
        return returnType
    }
}



/// Return code declaration for functions/methods/convenience constructors
public func returnDeclarationCode(_ tr: (typeName: String, record: GIR.Record, isConstructor: Bool)? = nil) -> (GIR.Method) -> String {
    return { method in
        let throwCode = method.throwsError ? " throws" : ""
        guard let returnType = returnTypeCode(tr)(method) else { return throwCode }
        return throwCode + " -> \(returnType)"
    }
}


/// Return code for functions/methods/convenience constructors
public func returnCode(_ indentation: String, _ tr: (typeName: String, record: GIR.Record, isConstructor: Bool, isConvenience: Bool)? = nil) -> (GIR.Method) -> String {
    return { method in
        let rv = method.returns
        guard !rv.isVoid else { return "" }
        let isInstance = rv.isInstanceOf(tr?.record)
        let cast2swift = typeCastTuple(rv.ctype, rv.type.swift, forceCast: isInstance).toSwift
        guard isInstance else { return indentation + "return \(cast2swift)\n" + indentation }
        let (cons, cast, end) = tr!.isConstructor ? ("self.init", cast2swift, "") : ("return rv.map { \(tr!.typeName)", "cast($0)", " }")
        if tr!.isConvenience || !tr!.isConstructor {
            return indentation + "\(cons)(ptr: \(cast))\(end)\n" + indentation
        } else {
            return indentation + "self.ptr = \(cast2swift)\n" + indentation
        }
    }
}


/// Swift code for calling the underlying function and assigning the raw return value
public func callCode(_ indentation: String, _ record: GIR.Record? = nil) -> (GIR.Method) -> String {
    let toSwift = convertArgumentToSwiftFor(record)
    return { method in
        let throwsError = method.throwsError
        let args = method.args // not .lazy
        let n = args.count
        let rv = method.returns
        let isVoid = rv.isVoid
        let code = ( throwsError ? "var error: Optional<UnsafeMutablePointer<\(gerror)>> = nil\n" + indentation : "") +
        ( isVoid ? "" : "let rv = " ) +
        "\(method.cname.swift)(\(args.map(toSwift).joined(separator: ", "))" +
            ( throwsError ? ((n == 0 ? "" : ", ") + "&error)\n" + indentation + "if let error = error {\n" + indentation + indentation + "throw ErrorType(ptr: error)\n" + indentation + "}\n") : ")\n" )
        return code
    }
}


/// Swift code for calling the underlying setter function and assigning the raw return value
public func callSetter(_ indentation: String, _ record: GIR.Record? = nil) -> (GIR.Method) -> String {
    let toSwift = convertSetterArgumentToSwiftFor(record)
    return { method in
        let args = method.args // not .lazy
        let code = ( method.returns.isVoid ? "" : "let _ = " ) +
            "\(method.cname.swift)(\(args.map(toSwift).joined(separator: ", ")))\n"
        return code
    }
}


/// Swift code for the parameters of a method or function
public func funcParam(_ method: GIR.Method, _ record: GIR.Record? = nil) -> String {
    return method.args.lazy.filter { !$0.instance && !$0.isInstanceOf(record) } .map(argumentCode).joined(separator: ", ")
}


/// Swift code for the parameters of a constructor
public func constructorParam(_ method: GIR.Method) -> String {
    return method.args.lazy.map(argumentCode).joined(separator: ", ")
}


/// Swift code for constructor prefix extracted from a method name
public func constructorPrefix(_ method: GIR.Method) -> String {
    let cname = method.cname
    let components = cname.split(separator: "_")
    guard let from = components.lazy.enumerated().filter({ $0.1 == "from" }).first else {
        let mn = method.name
        let name = mn.isEmpty ? cname : mn
        let unPrefixed: String
        if let prefix = (["new_", "new"].lazy.filter { name.hasPrefix($0) }.first) {
            let chars = name.characters
            let s = chars.index(chars.startIndex, offsetBy: prefix.characters.count)
            let e = chars.endIndex
            unPrefixed = String(chars[s..<e])
        } else {
            unPrefixed = name
        }
        let shortened: String
        if let suffix = (["_new"].lazy.filter { unPrefixed.hasSuffix($0) }.first) {
            let chars = unPrefixed.characters
            let s = chars.startIndex
            let e = chars.index(chars.endIndex, offsetBy: -suffix.characters.count)
            shortened = String(chars[s..<e])
        } else {
            shortened = unPrefixed
        }
        return shortened.swift
    }
    let f = components.startIndex + from.offset + 1
    let e = components.endIndex
    let s = f < e ? f : f - 1
    let name = components[s..<e].joined(separator: "_")
    return name.swift
}


/// Swift code for methods
public func argumentCode(_ arg: GIR.Argument) -> String {
    let prefixedname = arg.prefixedArgumentName
    let type = arg.argumentType
    let code = "\(prefixedname): \(type)"
    return code
}


/// Swift code for passing an argument to a free standing function
public func toSwift(_ arg: GIR.Argument) -> String {
    let types = typeCastTuple(arg.ctype, arg.type.swift, varName: arg.instance ? "ptr" : (arg.nonClashingName + (arg.isKnownRecord ? ".ptr" : "")))
    let param = types.toC.hasSuffix("ptr") ? "cast(\(types.toC))" : types.toC
    return param
}


/// Swift code for passing an argument to a method of a record / class
public func convertArgumentToSwiftFor(_ record: GIR.Record?) -> (GIR.Argument) -> String {
    return { arg in
        let name = arg.nonClashingName
        guard !arg.isScalarArray else { return "&" + name }
        let types = typeCastTuple(arg.ctype, arg.type.swift, varName: arg.instance || arg.isInstanceOf(record) ? "ptr" : (name + (arg.isKnownRecord ? ".ptr" : "")))
        let param = types.toC.hasSuffix("ptr") ? "cast(\(types.toC))" : types.toC
        return param
    }
}


/// Swift code for passing a setter to a method of a record / class
public func convertSetterArgumentToSwiftFor(_ record: GIR.Record?) -> (GIR.Argument) -> String {
    return { arg in
        let name = arg.nonClashingName
        guard !arg.isScalarArray else { return "&" + name }
        let types = typeCastTuple(arg.ctype, arg.type.swift, varName: arg.instance || arg.isInstanceOf(record) ? "ptr" : ("newValue"))
        let param = types.toC.hasSuffix("ptr") ? "cast(\(types.toC))" : types.toC
        return param
    }
}



/// Swift struct representation of a record/class as a wrapper of a pointer
public func recordStructCode(_ e: GIR.Record, indentation: String = "    ") -> String {
    let structType = "\(e.name)Ref"
    let ccode = convenienceConstructorCode(structType, indentation: indentation)(e)
    let fcode = convenienceConstructorCode(structType, indentation: indentation, factory: true)(e)
    let constructors = e.constructors.filter { $0.isConstructorOf(e) && !$0.isBareFactory }
    let factories = (e.constructors + e.methods + e.functions).filter { $0.isFactoryOf(e) }
    let code = "public struct \(structType): \(e.protocolName) {\n" + indentation +
        "public let ptr: UnsafeMutablePointer<\(e.ctype.swift)>\n" +
    "}\n\n" +
    "public extension \(structType) {\n" + indentation +
        "public init<T>(cPointer: UnsafeMutablePointer<T>) {\n" + indentation + indentation +
            "ptr = UnsafeMutablePointer<\(e.ctype.swift)>(cPointer)\n" + indentation +
        "}\n\n" + indentation +
        "public init<T>(constPointer: UnsafePointer<T>) {\n" + indentation + indentation +
            "ptr = UnsafeMutablePointer<\(e.ctype.swift)>(constPointer)\n" + indentation +
        "}\n\n" + indentation +
        "public init(opaquePointer: OpaquePointer) {\n" + indentation + indentation +
            "ptr = UnsafeMutablePointer<\(e.ctype.swift)>(opaquePointer)\n" + indentation +
        "}\n\n" + indentation +
        constructors.map(ccode).joined(separator: "\n") +
        factories.map(fcode).joined(separator: "\n") +
    "}\n\n"

    return code
}


/// Swift struct representation of a record/class as a wrapper of a pointer
public func recordClassCode(_ e: GIR.Record, parent: String, indentation: String = "    ") -> String {
    let classType = e.name.swift
    let ccode = convenienceConstructorCode(classType, indentation: indentation, convenience: "convenience")(e)
    let fcode = convenienceConstructorCode(classType, indentation: indentation, factory: true)(e)
    let constructors = e.constructors.filter { $0.isConstructorOf(e) && !$0.isBareFactory }
    let allmethods = e.constructors + e.methods + e.functions
    let factories = allmethods.filter { $0.isFactoryOf(e) }
    let release: String
    if let unref = allmethods.lazy.filter({ $0.isUnref }).first {
        release = unref.cname
    } else {
        release = "g_free"
    }
    let p = parent.isEmpty ? "" : "\(parent), "
    let code = "public class \(classType): \(p)\(e.protocolName) {\n" + indentation +
        "public let ptr: UnsafeMutablePointer<\(e.ctype.swift)>\n\n" + indentation +
        "public init(ptr: UnsafeMutablePointer<\(e.ctype.swift)>) {\n" + indentation + indentation +
            "self.ptr = ptr\n" + indentation +
        "}\n\n" + indentation +
        "deinit {\n" + indentation + indentation +
            "\(release)(cast(ptr))\n" + indentation +
        "}\n\n" +
    "}\n\n" +
        "public extension \(classType) {\n" + indentation +
        "public convenience init<T>(cPointer: UnsafeMutablePointer<T>) {\n" + indentation + indentation +
            "self.init(ptr: UnsafeMutablePointer<\(e.ctype.swift)>(cPointer))\n" + indentation +
        "}\n\n" + indentation +
//        "public convenience init<T>(cPointer: UnsafePointer<T>) {\n" + indentation + indentation +
//        "    self.init(ptr: UnsafeMutablePointer<\(e.ctype.swift)>(cPointer))\n" + indentation +
//        "}\n\n" + indentation +
        "public convenience init(opaquePointer: OpaquePointer) {\n" + indentation + indentation +
            "self.init(ptr: UnsafeMutablePointer<\(e.ctype.swift)>(opaquePointer))\n" + indentation +
        "}\n\n" + indentation +
        constructors.map(ccode).joined(separator: "\n") +
        factories.map(fcode).joined(separator: "\n") +
    "}\n\n"

    return code
}




/// Swift code representation of a record
public func swiftCode(_ e: GIR.Record) -> String {
    let parentProtocol = e.ctype == gerror ? errorProtocol : ""
    let p = recordProtocolCode(e, parent: parentProtocol)
    let s = recordStructCode(e)
    let c = recordClassCode(e, parent: "")
    let e = recordProtocolExtensionCode(e)
    let code = p + s + c + e
    return code
}


/// Swift code representation of a free standing function
public func swiftCode(_ f: GIR.Function) -> String {
    let code = functionCode(f)
    return code
}
