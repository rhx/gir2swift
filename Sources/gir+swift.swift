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
        "    return param?.withMemoryRebound(to: T.self, capacity: 1) { $0 }\n" +
        "}\n\n" +

        "private func cast<S, T>(_ param: UnsafeMutablePointer<S>?) -> UnsafePointer<T>! {\n" +
        "    return param?.withMemoryRebound(to: T.self, capacity: 1) { UnsafePointer<T>($0) }\n" +
        "}\n\n" +

        "private func cast<S, T>(_ param: UnsafePointer<S>?) -> UnsafePointer<T>! {\n" +
        "    return param?.withMemoryRebound(to: T.self, capacity: 1) { UnsafePointer<T>($0) }\n" +
        "}\n\n" +

        "private func cast<T>(_ param: OpaquePointer?) -> UnsafeMutablePointer<T>! {\n" +
        "    return UnsafeMutablePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast<T>(_ param: OpaquePointer?) -> UnsafePointer<T>! {\n" +
        "    return UnsafePointer<T>(param)\n" +
        "}\n\n" +

        "private func cast(_ param: OpaquePointer?) -> UnsafeMutableRawPointer! {\n" +
        "    return UnsafeMutableRawPointer(param)\n" +
        "}\n\n" +

//        "private func cast<S, T>(_ param: UnsafePointer<S>?) -> UnsafeMutablePointer<T>! {\n" +
//        "    return param?.withMemoryRebound(to: T.self, capacity: 1) { $0 }\n" +
//        "}\n\n" +

        "private func cast<T>(_ param: UnsafePointer<T>?) -> OpaquePointer! {\n" +
        "    return OpaquePointer(param)\n" +
        "}\n\n" +

        "private func cast<T>(_ param: UnsafeMutablePointer<T>?) -> OpaquePointer! {\n" +
        "    return OpaquePointer(param)\n" +
        "}\n\n" +

//        "private func cast<T>(_ param: UnsafePointer<T>?) -> UnsafeRawPointer! {\n" +
//        "    return UnsafeRawPointer(param)\n" +
//        "}\n\n" +
//
//        "private func cast<T>(_ param: UnsafeMutablePointer<T>?) -> UnsafeRawPointer! {\n" +
//        "    return UnsafeRawPointer(param)\n" +
//        "}\n\n" +
//
//        "private func cast<T>(_ param: UnsafePointer<T>?) -> UnsafeMutableRawPointer! {\n" +
//        "    return UnsafeMutableRawPointer(mutating: UnsafeRawPointer(param))\n" +
//        "}\n\n" +
//
//        "private func cast<T>(_ param: UnsafeMutablePointer<T>?) -> UnsafeMutableRawPointer! {\n" +
//        "    return UnsafeMutableRawPointer(param)\n" +
//        "}\n\n" +
//
//        "private func cast<T>(_ param: UnsafeRawPointer?) -> UnsafePointer<T>! {\n" +
//        "    return param?.assumingMemoryBound(to: T.self)\n" +
//        "}\n\n" +
//
//        "private func cast<T>(_ param: UnsafeMutableRawPointer?) -> UnsafePointer<T>! {\n" +
//        "    return UnsafeRawPointer(param)?.assumingMemoryBound(to: T.self)\n" +
//        "}\n\n" +

        "private func cast<T>(_ param: UnsafeRawPointer?) -> UnsafeMutablePointer<T>! {\n" +
        "    return UnsafeMutableRawPointer(mutating: param)?.assumingMemoryBound(to: T.self)\n" +
        "}\n\n" +

        "private func cast<T>(_ param: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<T>! {\n" +
        "    return param?.assumingMemoryBound(to: T.self)\n" +
        "}\n\n" +

        "private func cast<T>(_ param: T) -> T { return param }\n\n" +

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
        "    param.withMemoryRebound(to: T.self, capacity: rv.count) { release(UnsafePointer<T>($0)) }\n" +
        "    return rv\n" +
        "}\n\n"
    }
}


/// Swift extentsion for things
public extension GIR.Thing {
    /// return a name with reserved Ref or Protocol suffixes escaped
    public var escapedName: String {
        let na = name.typeEscaped
        return na
    }
}


/// Swift extension for arguments
public extension GIR.Argument {
    //// return the known type of the argument (nil if not known)
    public var knownType: GIR.Datatype? { return GIR.KnownTypes[type.isEmpty ? ctype : type] }

    //// return the known class/record of the argument (nil if not known)
    public var knownRecord: GIR.Record? { return GIR.KnownRecords[type.isEmpty ? ctype : type] }

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

    /// return the non-prefixed argument name
    public var argumentName: String { return nonClashingName }

    /// return the, potentially prefixed argument name to use in a method declaration
    public var prefixedArgumentName: String {
        let name = argumentName
        let swname = name.camelCase.swift
        let prefixedname = name == swname ? name : (swname + " " + name)
        return prefixedname
    }

    /// return the swift (known) type of the receiver
    public var argumentType: String {
        let ct = ctype
        let t = type.isEmpty ? ct : type
        let array = isScalarArray
        let swift = (array ? t.swiftType : t.swift).typeEscaped
        let isPtr  = ct.isPointer
        let record = knownRecord
        let code = "\(array ? "inout [" : "")\(isPtr ? (record.map { $0.protocolName } ?? ct.swiftRepresentationOfCType) : swift)\(array ? "]" : "")"
        return code
    }

    /// return whether the receiver is an instance of the given record (class)
    public func isInstanceOf(_ record: GIR.Record?) -> Bool {
        if let r = record, r.name == type.withoutNameSpace {
            return true
        } else {
            return false
        }
    }

    /// return whether the receiver is an instance of the given record (class) or any of its ancestors
    public func isInstanceOfHierarchy(_ record: GIR.Record) -> Bool {
        if isInstanceOf(record) { return true }
        guard let parent = record.parentType else { return false }
        return isInstanceOfHierarchy(parent)
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
        return record != nil && returns.isInstanceOfHierarchy(record!) && !(args.first?.isInstanceOf(record) ?? false)
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
        let n = getter.name.utf16 
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
                if let u = String(n[i..<j])?.unicodeScalars.first, u.isASCII {
                    let c = Int32(u.value)
                    if let upper = UnicodeScalar(UInt16(toupper(c))), islower(c) != 0 {
                        name += String(Character(upper))
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
        return String(describing: a) <= String(describing: b)
    }
    var pairs = Array<GetterSetterPair>()
    pairs.reserveCapacity(gettersAndSetters.count)
    var i = gettersAndSetters.makeIterator()
    var b = i.next()
    while let a = b {
        b = i.next()
        if a.isGetter {
            guard let s = b, s.isSetterFor(getter: a.name) else { pairs.append(GetterSetterPair(getter: a, setter: nil)) ; continue }
            pairs.append(GetterSetterPair(getter: a, setter: s))
        } else {    // isSetter
            guard let g = b, g.isGetterFor(setter: a.name) else { continue }
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
        t = s + "\n\(indentation)///\n\(indentation)/// **\(thing.name) is deprecated:**\n" + d + "\n"
    } else {
        t = s
    }
    return t + ((t.isEmpty || t.hasSuffix("\n")) ? "" : "\n") + postfix
}

/// Swift code representation of a type alias
public func swiftCode(alias: GIR.Alias) -> String {
    return swiftCode(alias, "public typealias \(alias.escapedName.swift) = \(alias.type.swift)")
}

/// Swift code representation of a callback as a type alias
public func swiftCallbackAliasCode(callback: GIR.Callback) -> String {
    return swiftCode(callback, "public typealias \(callback.escapedName.swift) = \(callback.type.swift)")
}

/// Swift code representation of a constant
public func swiftCode(constant: GIR.Constant) -> String {
    let type = constant.type.swift
    let name = constant.escapedName.swift
    guard !GIR.VerbatimConstants.contains(name) else {
        return swiftCode(constant, "public let \(name): \(constant.ctype.swift) = \(constant.value) /* \(type) */")
    }
    return swiftCode(constant, "public let \(name) = \(type) /* \(constant.ctype) \(constant.value) */")
}

/// Magic error type for throwing
let errorProtocol = "Error"

/// error type enum
let errorType = "ErrorType"

/// underlying error type
let gerror = "GError"

/// Swift code type alias representation of an enum
public func typeAlias(_ e: GIR.Enumeration) -> String {
    return swiftCode(e, "public typealias \(e.escapedName.swift) = \(e.type.swift)")
}

/// Swift code representation of an enum
public func swiftCode(_ e: GIR.Enumeration) -> String {
    let alias = typeAlias(e)
    let name = e.escapedName
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
        swiftCode(m, indentation + "public static let \(m.name.swiftName) = \(m.ctype.swift) /* \(m.value) */", indentation: indentation)
    }
}


/// Swift protocol representation of a record/class as a wrapper of a pointer
public func recordProtocolCode(_ e: GIR.Record, parent: String, indentation: String = "    ") -> String {
    let ctype = e.ctype.isEmpty ? e.type.swift : e.ctype.swift
    let p = (parent.isEmpty ? "" : ": \(parent)")
    let code = "// MARK: - \(e.name)\n" +
        "public protocol \(e.protocolName)\(p) {\n" + (e.parentType == nil ?
        (indentation + "var ptr: UnsafeMutablePointer<\(ctype)> { get }\n") : "") +
    "}\n\n"
    return code
}


/// Default implementation for record methods as protocol extension
public func recordProtocolExtensionCode(_ globalFunctions: [GIR.Function], _ e: GIR.Record, indentation: String = "    ") -> String {
    let mcode = methodCode(indentation, record: e)
    let vcode = computedPropertyCode(indentation, record: e)
    let allMethods = e.methods + (e.functions + globalFunctions).filter {
        let fun = $0
        return fun.args.lazy.filter({ (arg: GIR.Argument) -> Bool in
            arg.isInstanceOf(e)
        }).first != nil
    }
    let gsPairs = getterSetterPairs(for: allMethods)
    let methods = allMethods.filter { method in
        !method.name.hasPrefix("is_") || !gsPairs.contains { $0.getter === method } }
    let code = "public extension \(e.protocolName) {\n" +
        methods.map(mcode).joined(separator: "\n") +
        gsPairs.map(vcode).joined(separator: "\n") +
    "}\n\n"
    return code
}


/// Default implementation for functions
public func functionCode(_ f: GIR.Function, indentation: String = "    ", initialIndentation i: String = "") -> String {
    let mcode = methodCode(indentation, initialIndentation: i)
    let code = mcode(f) + "\n\n"
    return code
}


/// Swift code for methods (with a given indentation)
public func methodCode(_ indentation: String, initialIndentation: String? = nil, record: GIR.Record? = nil, convertName: @escaping (String) -> String = { $0.camelCase }) -> (GIR.Method) -> String {
    let indent = initialIndentation ?? indentation
    let doubleIndent = indent + indentation
    let call = callCode(doubleIndent, record)
    let returnDeclaration = returnDeclarationCode()
    let ret = returnCode(indentation)

    return { (method: GIR.Method) -> String in
        let rawName = method.name.isEmpty ? method.cname : method.name
        let name = convertName(rawName)
        guard !GIR.Blacklist.contains(rawName) && !GIR.Blacklist.contains(name) else {
            return "\n\(indent)// *** \(name)() causes a syntax error and is therefore not available!\n\n"
        }
        guard !method.varargs else {
            return "\n\(indent)// *** \(name)() is not available because it has a varargs (...) parameter!\n\n"
        }
        var hadInstance = false
        let params = method.args.filter {    // not .lazy !!!
            guard !hadInstance else {
                return true
            }
            let instance = $0.instance || $0.isInstanceOf(record)
            if instance { hadInstance = true }
            return !instance
        } .map(codeFor)
        let funcParam = params.joined(separator: ", ")
        let fname: String
        if let firstParamName = params.first?.split(separator: " ").first?.split(separator: ":").first?.capitalised {
            fname = name.stringByRemoving(suffix: firstParamName) ?? name
        } else {
            fname = name
        }
        let deprecated = method.deprecated != nil ? "@available(*, deprecated) " : ""
        let code = swiftCode(method, indent + "\(deprecated)public func \(fname.swift)(" +
            funcParam + ")\(returnDeclaration(method)) {\n" +
                doubleIndent + call(method) +
                indent       + ret(method)  + indent +
        "}\n", indentation: indent)
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
        let name = pair.name.swiftName
        let getter = pair.getter
        let gs: GIR.Method
        let type: String
        if let rt = returnTypeCode()(getter) {
            gs = getter
            type = rt
        } else {
            let setter = pair.setter
            guard let args = setter?.args.filter({ !$0.isInstanceOf(record) }),
                  let at = args.first, args.count == 1 else {
                return indentation + "// var \(name) is unavailable because it does not have a valid getter or setter\n"
            }
            type = at.argumentType
            gs = setter!
        }
        let property: GIR.CType
        if let prop = record.properties.filter({ $0.name.swiftName == name }).first {
            property = prop
        } else {
            property = gs
        }
        let varDecl = swiftCode(property, indentation + "public var \(name): \(type) {\n", indentation: indentation)
        let deprecated = getter.deprecated != nil ? "@available(*, deprecated) " : ""
        let getterCode = swiftCode(getter, doubleIndent + "\(deprecated)get {\n" +
            doubleIndent + indentation + gcall(getter) +
            indentation  + ret(getter) + doubleIndent +
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
public func convenienceConstructorCode(_ typeName: String, indentation: String, convenience: String = "", factory: Bool = false, convertName: @escaping (String) -> String = { $0.camelCase }) -> (GIR.Record) -> (GIR.Method) -> String {
    let isConv = !convenience.isEmpty
    let conv =  isConv ? "\(convenience) " : ""
    return { (record: GIR.Record) -> (GIR.Method) -> String in
        let doubleIndent = indentation + indentation
        let call = callCode(doubleIndent)
        let returnDeclaration = returnDeclarationCode((typeName: typeName, record: record, isConstructor: !factory))
        let ret = returnCode(indentation, (typeName: typeName, record: record, isConstructor: !factory, isConvenience: isConv))
        return { (method: GIR.Method) -> String in
            let rawName = method.name.isEmpty ? method.cname : method.name
            let rawUTF = rawName.utf16
            let firstArgName = method.args.first?.name
            let nameWithoutPostFix: String
            if let f = firstArgName, rawUTF.count > f.utf16.count + 1 && rawName.hasSuffix(f) {
                let truncated = rawUTF[rawUTF.startIndex..<rawUTF.index(rawUTF.endIndex, offsetBy: -f.utf16.count)]
                if truncated.last == _U {
                    nameWithoutPostFix = String(describing: rawUTF[rawUTF.startIndex..<rawUTF.index(rawUTF.endIndex, offsetBy: -(f.utf16.count+1))])
                } else {
                    nameWithoutPostFix = String(describing: truncated)
                }
            } else {
                nameWithoutPostFix = rawName
            }
            let name = convertName(nameWithoutPostFix)
            guard !GIR.Blacklist.contains(rawName) && !GIR.Blacklist.contains(name) else {
                return "\n\(indentation)// *** \(name)() causes a syntax error and is therefore not available!\n\n"
            }
            guard !method.varargs else {
                return "\n\(indentation)// *** \(name)() is not available because it has a varargs (...) parameter!\n\n"
            }
            let deprecated = method.deprecated != nil ? "@available(*, deprecated) " : ""
            let override = record.inheritedMethods.filter { $0.name == rawName }.first != nil
            let fullname = override ? convertName((method.cname.afterFirst() ?? (record.name + nameWithoutPostFix.capitalised))) : name
            let consPrefix = constructorPrefix(method)
            let fname: String
            if let prefix = consPrefix?.capitalised {
                fname = fullname.stringByRemoving(suffix: prefix) ?? fullname
            } else {
                fname = fullname
            }
            let p: String? = consPrefix == firstArgName?.swift ? nil : consPrefix
            let fact = factory ? "static func \(fname.swift)(" : "\(conv)init("
            let code = swiftCode(method, indentation + "\(deprecated)public \(fact)" +
                constructorParam(method, prefix: p) + ")\(returnDeclaration(method)) {\n" +
                    doubleIndent + call(method) +
                    indentation  + ret(method)  + indentation +
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
        if tr != nil && rv.isInstanceOfHierarchy((tr?.record)!)  {
            returnType = tr!.typeName + "!"
        } else {
            let rt = typeCastTuple(rv.ctype, rv.type.swift).swift
            returnType = rv.isAnyKindOfPointer ? "\(rt)!" : rt
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
        guard !rv.isVoid else { return "\n" }
        let isInstance = tr?.record != nil && rv.isInstanceOfHierarchy((tr?.record)!)
        let cast2swift = typeCastTuple(rv.ctype, rv.type.swift, forceCast: isInstance).toSwift
        guard isInstance else { return indentation + "return \(cast2swift)\n" }
        let (cons, cast, end) = tr!.isConstructor ? ("self.init", cast2swift, "") : ("return rv.map { \(tr!.typeName)", "cast($0)", " }")
        if tr!.isConvenience || !tr!.isConstructor {
            return indentation + "\(cons)(\(cast))\(end)\n"
        } else {
            return indentation + "self.ptr = \(cast2swift)\n"
        }
    }
}


/// Swift code for calling the underlying function and assigning the raw return value
public func callCode(_ indentation: String, _ record: GIR.Record? = nil) -> (GIR.Method) -> String {
    var hadInstance = false
    let toSwift: (GIR.Argument) -> String = { arg in
        let name = arg.nonClashingName
        guard !arg.isScalarArray else { return "&" + name }
        let instance = !hadInstance && (arg.instance || arg.isInstanceOf(record))
        if instance { hadInstance = true }
        let types = typeCastTuple(arg.ctype, arg.type.swift, varName: instance ? "ptr" : (name + (arg.isKnownRecord ? ".ptr" : "")))
        let param = types.toC.hasSuffix("ptr") ? "cast(\(types.toC))" : types.toC
        return param
    }
    return { method in
        hadInstance = false
        let throwsError = method.throwsError
        let args = method.args // not .lazy
        let n = args.count
        let rv = method.returns
        let isVoid = rv.isVoid
        let code = ( throwsError ? "var error: Optional<UnsafeMutablePointer<\(gerror)>> = nil\n" + indentation : "") +
        ( isVoid ? "" : "let rv = " ) +
        "\(method.cname.swift)(\(args.map(toSwift).joined(separator: ", "))" +
            ( throwsError ? ((n == 0 ? "" : ", ") + "&error)\n" + indentation + "if let error = error {\n" + indentation + indentation + "throw ErrorType(error)\n" + indentation + "}\n") : ")\n" )
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



/// Swift code for the parameters of a constructor
public func constructorParam(_ method: GIR.Method, prefix: String?) -> String {
    let comma = ", "
    let args = method.args
    guard let first = args.first else { return "" }
    guard let p = prefix else { return args.map(codeFor).joined(separator: comma) }
    let firstParam = codeFor(argument: first, prefix: p)
    let n = args.count
    guard n > 1 else { return firstParam }
    let tail = args[1..<n]
    return firstParam + comma + tail.map(codeFor).joined(separator: comma)
}


/// Swift code for constructor first argument prefix extracted from a method name
public func constructorPrefix(_ method: GIR.Method) -> String? {
    guard !method.args.isEmpty else { return nil }
    let cname = method.cname
    let components = cname.split(separator: "_")
    guard let from = components.lazy.enumerated().filter({ $0.1 == "from" || $0.1 == "for" || $0.1 == "with" }).first else {
        let mn = method.name
        let name = mn.isEmpty ? cname : mn
        guard name != "newv" else { return nil }
        if let prefix = (["new_", "new"].lazy.filter { name.hasPrefix($0) }.first) {
            let chars = name.characters
            let s = chars.index(chars.startIndex, offsetBy: prefix.characters.count)
            let e = chars.endIndex
            return String(chars[s..<e]).swift
        }
        if let suffix = (["_newv", "_new"].lazy.filter { name.hasSuffix($0) }.first) {
            let chars = name.characters
            let s = chars.startIndex
            let e = chars.index(chars.endIndex, offsetBy: -suffix.characters.count)
            return String(chars[s..<e]).swift
        }
        return nil
    }
    let f = components.startIndex + from.offset + 1
    let e = components.endIndex
    let s = f < e ? f : f - 1
    let name = components[s..<e].joined(separator: "_")
    return name.camelCase.swift
}


/// Swift code for auto-prefixed arguments
public func codeFor(argument a: GIR.Argument) -> String {
    let prefixedname = a.prefixedArgumentName
    let type = a.argumentType
    let code = "\(prefixedname): \(type)"
    return code
}


/// Swift code for methods
public func codeFor(argument a: GIR.Argument, prefix: String) -> String {
    let name = a.argumentName
    let type = a.argumentType
    let code = "\(prefix) \(name): \(type)"
    return code
}


/// Swift code for passing an argument to a free standing function
public func toSwift(_ arg: GIR.Argument) -> String {
    let types = typeCastTuple(arg.ctype, arg.type.swift, varName: arg.instance ? "ptr" : (arg.nonClashingName + (arg.isKnownRecord ? ".ptr" : "")))
    let param = types.toC.hasSuffix("ptr") ? "cast(\(types.toC))" : types.toC
    return param
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


/// Swift code for signal names without prefixes
public func signalNameCode(indentation indent: String, convertName: @escaping (String) -> String = { $0.camelSignal }) -> (GIR.CType) -> String {
    return signalNameCode(indentation: indent, prefixes: ("", ""), convertName: convertName)
}


/// Swift code for signal names with prefixes
public func signalNameCode(indentation indent: String, prefixes: (String, String), convertName: @escaping (String) -> String = { $0.camelSignalComponent }) -> (GIR.CType) -> String {
    return { signal in
        let name = signal.name
        let declaration = indent + "case \(prefixes.0)\(convertName(name).swift) = \"\(prefixes.1)\(name)\""
        let code = swiftCode(signal, declaration, indentation: indent)
        return code
    }
}


/// Swift struct representation of a record/class as a wrapper of a pointer
public func recordStructCode(_ e: GIR.Record, indentation: String = "    ") -> String {
    let structType = "\(e.name)Ref"
    let protocolName = e.protocolName
    let parent = e.parentType
    let root = parent?.rootType
    let p = parent ?? e
    let r = root ?? p
    let ctype = e.ctype.isEmpty ? e.type.swift : e.ctype.swift
    let rtype = r.ctype.isEmpty ? r.type.swift : r.ctype.swift
    let ccode = convenienceConstructorCode(structType, indentation: indentation)(e)
    let fcode = convenienceConstructorCode(structType, indentation: indentation, factory: true)(e)
    let constructors = e.constructors.filter { $0.isConstructorOf(e) && !$0.isBareFactory }
    let factories = (e.constructors + e.methods + e.functions).filter { $0.isFactoryOf(e) }
    let code = "public struct \(structType): \(protocolName) {\n" + indentation +
        "public let ptr: UnsafeMutablePointer<\(rtype)>\n" +
    "}\n\n" +
    "public extension \(structType) {\n" + indentation +
        "public init(_ p: UnsafeMutablePointer<\(ctype)>) {\n" + indentation + indentation +
            "ptr = p" +
            (ctype == rtype ? "\n" : ".withMemoryRebound(to: \(rtype).self, capacity: 1) { $0 }\n") + indentation +
        "}\n\n" + indentation +
        "public init<T: \(protocolName)>(_ other: T) {\n" + indentation + indentation +
            "ptr = other.ptr\n" + indentation +
        "}\n\n" + indentation +
        "public init<T>(cPointer: UnsafeMutablePointer<T>) {\n" + indentation + indentation +
            "ptr = cPointer.withMemoryRebound(to: \(rtype).self, capacity: 1) { $0 }\n" + indentation +
        "}\n\n" + indentation +
        "public init<T>(constPointer: UnsafePointer<T>) {\n" + indentation + indentation +
            "ptr = constPointer.withMemoryRebound(to: \(rtype).self, capacity: 1) { $0 }\n" + indentation +
        "}\n\n" + indentation +
        "public init(raw: UnsafeRawPointer) {\n" + indentation + indentation +
            "ptr = UnsafeMutableRawPointer(mutating: raw).assumingMemoryBound(to: \(rtype).self)\n" + indentation +
        "}\n\n" + indentation +
        "public init(raw: UnsafeMutableRawPointer) {\n" + indentation + indentation +
            "ptr = raw.assumingMemoryBound(to: \(rtype).self)\n" + indentation +
        "}\n\n" + indentation +
        "public init(opaquePointer: OpaquePointer) {\n" + indentation + indentation +
            "ptr = UnsafeMutablePointer<\(rtype)>(opaquePointer)\n" + indentation +
        "}\n\n" + indentation +
        constructors.map(ccode).joined(separator: "\n") +
        factories.map(fcode).joined(separator: "\n") +
    "}\n\n"

    return code
}


/// Swift struct representation of a record/class as a wrapper of a pointer
public func recordClassCode(_ e: GIR.Record, parent: String, indentation: String = "    ") -> String {
    let doubleIndentation = indentation + indentation
    let tripleIndentation = indentation + doubleIndentation
    let classType = e.name.swift
    let protocolName = e.protocolName
    let parentType = e.parentType
    let hasParent = parentType != nil
    let ctype = e.ctype.isEmpty ? e.type.swift : e.ctype.swift
    let scode = signalNameCode(indentation: indentation)
    let ncode = signalNameCode(indentation: indentation, prefixes: ("notify", "notify::"))
    let ccode = convenienceConstructorCode(classType, indentation: indentation, convenience: "convenience")(e)
    let fcode = convenienceConstructorCode(classType, indentation: indentation, factory: true)(e)
    let constructors = e.constructors.filter { $0.isConstructorOf(e) && !$0.isBareFactory }
    let allmethods = e.allMethods
    let factories = allmethods.filter { $0.isFactoryOf(e) }
    let properties = e.allProperties
    let signals = e.allSignals
    let noProperties = properties.isEmpty
    let noSignals = noProperties && signals.isEmpty
    let retain: String
    if let ref = e.ref {
        retain = ref.cname
    } else {
        retain = "// no reference counting for \(e.ctype.swift), cannot ref"
    }
    let release: String
    if let unref = e.unref {
        release = unref.cname
    } else {
        release = "// no reference counting for \(e.ctype.swift), cannot unref"
    }
    let parentName = hasParent ? parentType!.name.swift : ""
    let p = parent.isEmpty ? (hasParent ? "\(parentName), " : "") : "\(parent), "
    let code = "open class \(classType): \(p)\(protocolName) {\n" + indentation +
        (hasParent ? "" : ("public let ptr: UnsafeMutablePointer<\(ctype)>\n\n" + indentation)) +
        "public init(_ op: UnsafeMutablePointer<\(ctype)>) {\n" + indentation + indentation +
            (hasParent ? "super.init(cast(op))\n" : "self.ptr = op\n") + indentation +
        "}\n\n" + (hasParent ? "" : (indentation +
        "public convenience init<T: \(e.protocolName)>(_ other: T) {\n" + doubleIndentation +
            "self.init(other.ptr)\n" + doubleIndentation +
            "\(retain)(cast(ptr))\n" + indentation +
        "}\n\n" + indentation +
        "deinit {\n" + indentation + indentation +
            "\(release)(cast(ptr))\n" + indentation +
        "}\n\n")) + (hasParent ? "" : (indentation +
        "public convenience init<T>(cPointer: UnsafeMutablePointer<T>) {\n" + doubleIndentation +
            "self.init(cPointer.withMemoryRebound(to: \(ctype).self, capacity: 1) { $0 })\n" + indentation +
        "}\n\n" + indentation +
        "public convenience init(raw: UnsafeRawPointer) {\n" + doubleIndentation +
            "self.init(UnsafeMutableRawPointer(mutating: raw).assumingMemoryBound(to: \(ctype).self))\n" + indentation +
        "}\n\n" + indentation +
        "public convenience init(raw: UnsafeMutableRawPointer) {\n" + doubleIndentation +
            "self.init(raw.assumingMemoryBound(to: \(ctype).self))\n" + indentation +
        "}\n\n" + indentation +
        "public convenience init(opaquePointer: OpaquePointer) {\n" + doubleIndentation +
            "self.init(UnsafeMutablePointer<\(ctype)>(opaquePointer))\n" + indentation +
        "}\n\n")) +
        constructors.map(ccode).joined(separator: "\n") + "\n" +
        factories.map(fcode).joined(separator: "\n") + "\n" +
    "}\n\n" +
    (noProperties ? "// MARK: - no \(classType) properties\n" : "public enum \(classType)PropertyName: String, PropertyNameProtocol {\n") +
//        "public typealias Class = \(protocolName)\n") +
        properties.map(scode).joined(separator: "\n") + "\n" +
    (noProperties ? "" : ("}\n\npublic extension \(protocolName) {\n" + indentation +
        "@discardableResult public func bind<Q: PropertyNameProtocol, T: ObjectProtocol>(property source_property: \(classType)PropertyName, to target: T, _ target_property: Q, flags f: BindingFlags = .default_, transformFrom transform_from: GObject.ValueTransformer = { $0.transform(destValue: $1) }, transformTo transform_to: GObject.ValueTransformer = { $0.transform(destValue: $1) }) -> BindingRef! {\n" + doubleIndentation +
            "func _bind(_ source: UnsafePointer<gchar>, to t: T, _ target_property: UnsafePointer<gchar>, flags f: BindingFlags = .default_, holder: BindingClosureHolder, transformFrom transform_from: @convention(c) (gpointer, gpointer, gpointer, gpointer) -> gboolean, transformTo transform_to: @convention(c) (gpointer, gpointer, gpointer, gpointer) -> gboolean) -> BindingRef! {\n" + tripleIndentation +
                "let holder = UnsafeMutableRawPointer(Unmanaged.passRetained(holder).toOpaque())\n" + tripleIndentation +
                "let from = unsafeBitCast(transform_from, to: BindingTransformFunc.self)\n" + tripleIndentation +
                "let to   = unsafeBitCast(transform_to,   to: BindingTransformFunc.self)\n" + tripleIndentation +
                "let rv = GObject.ObjectRef(cast(ptr)).bindPropertyFull(sourceProperty: source, target: t, targetProperty: target_property, flags: f, transformTo: to, transformFrom: from, userData: holder) {\n" + tripleIndentation + indentation +
                    "if let swift = UnsafeRawPointer($0) {\n" + tripleIndentation + doubleIndentation +
                        "let holder = Unmanaged<GObject.SignalHandlerClosureHolder>.fromOpaque(swift)\n" + tripleIndentation + doubleIndentation +
                        "holder.release()\n" + tripleIndentation + indentation +
                    "}\n" + tripleIndentation +
                "}\n" + tripleIndentation +
                "return rv.map { BindingRef(cast($0)) }\n" + doubleIndentation +
            "}\n\n" + doubleIndentation +
            "let rv = _bind(source_property.name, to: target, target_property.name, flags: f, holder: BindingClosureHolder(transform_from, transform_to), transformFrom: {\n" + tripleIndentation +
                "let ptr = UnsafeRawPointer($3)\n" + tripleIndentation +
                "let holder = Unmanaged<BindingClosureHolder>.fromOpaque(ptr).takeUnretainedValue()\n" + tripleIndentation +
                "return holder.transform_from(GObject.ValueRef(raw: $1), GObject.ValueRef(raw: $2)) ? 1 : 0\n" + doubleIndentation +
        "}) {\n" + tripleIndentation +
            "let ptr = UnsafeRawPointer($3)\n" + tripleIndentation +
            "let holder = Unmanaged<BindingClosureHolder>.fromOpaque(ptr).takeUnretainedValue()\n" + tripleIndentation +
            "return holder.transform_to(GObject.ValueRef(raw: $1), GObject.ValueRef(raw: $2)) ? 1 : 0\n" + doubleIndentation +
        "}\n" + doubleIndentation +
        "return rv\n" + indentation +
    "}\n}\n\n")) +
    (noSignals ? "// MARK: - no signals\n" : "public enum \(classType)SignalName: String, SignalNameProtocol {\n") +
//        "public typealias Class = \(protocolName)\n") +
        signals.map(scode).joined(separator: "\n") + "\n" +
        properties.map(ncode).joined(separator: "\n") + "\n" +
    (noSignals ? "" : ("}\n\nextension \(protocolName) {\n" + indentation +
        "@discardableResult public func connect(signal kind: \(classType)SignalName, flags f: ConnectFlags = ConnectFlags(0), to handler: GObject.SignalHandler) -> CUnsignedLong {\n" + doubleIndentation +
            "func _connect(signal name: UnsafePointer<gchar>, flags: ConnectFlags, data: GObject.SignalHandlerClosureHolder, handler: @convention(c) (gpointer, gpointer) -> Void) -> CUnsignedLong {\n" + tripleIndentation +
                "let holder = UnsafeMutableRawPointer(Unmanaged.passRetained(data).toOpaque())\n" + tripleIndentation +
                "let callback = unsafeBitCast(handler, to: GObject.Callback.self)\n" + tripleIndentation +
                "let rv = GObject.ObjectRef(cast(ptr)).signalConnectData(detailedSignal: name, cHandler: callback, data: holder, destroyData: {\n" + tripleIndentation + indentation +
                    "if let swift = UnsafeRawPointer($0) {\n" + tripleIndentation + doubleIndentation +
                        "let holder = Unmanaged<GObject.SignalHandlerClosureHolder>.fromOpaque(swift)\n" + tripleIndentation + doubleIndentation +
                        "holder.release()\n" + tripleIndentation + indentation +
                    "}\n" + tripleIndentation + indentation +
                    "let _ = $1\n" + tripleIndentation +
                "}, connectFlags: flags)\n" + tripleIndentation +
                "return rv\n" + doubleIndentation +
            "}\n" + doubleIndentation +
            "let rv = _connect(signal: kind.name, flags: f, data: ClosureHolder(handler)) {\n" + tripleIndentation +
                "let ptr = UnsafeRawPointer($1)\n" + tripleIndentation +
                "let holder = Unmanaged<GObject.SignalHandlerClosureHolder>.fromOpaque(ptr).takeUnretainedValue()\n" + tripleIndentation +
                "holder.call()\n" + doubleIndentation +
            "}\n" + doubleIndentation +
            "return rv\n" + indentation +
        "}\n" +
    "}\n\n"))
    return code
}




/// Swift code representation of a record
public func swiftCode(_ funcs: [GIR.Function]) -> (GIR.Record) -> String {
    return { (e: GIR.Record) -> String in
        let parents = [ e.parentType?.protocolName ?? "", e.ctype == gerror ? errorProtocol : "" ].filter { !$0.isEmpty }
        let p = recordProtocolCode(e, parent: parents.joined(separator: ", "))
        let s = recordStructCode(e)
        let c = recordClassCode(e, parent: "")
        let e = recordProtocolExtensionCode(funcs, e)
        let code = p + s + c + e
        return code
    }
}


/// Swift code representation of a free standing function
public func swiftCode(_ f: GIR.Function) -> String {
    let code = functionCode(f)
    return code
}
