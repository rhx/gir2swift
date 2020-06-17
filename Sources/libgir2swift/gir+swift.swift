//
//  gir+swift.swift
//  gir2swift
//
//  Created by Rene Hexel on 2/04/2016.
//  Copyright © 2016, 2017, 2018, 2019, 2020 Rene Hexel. All rights reserved.
//
import Foundation

public extension GIR {
    /// code boiler plate
    var boilerPlate: String {
        return """

               func cast(_ param: UInt)   -> Int    {    Int(bitPattern: param) }
               func cast(_ param: Int)    -> UInt   {   UInt(bitPattern: param) }
               func cast(_ param: UInt16) -> Int16  {  Int16(bitPattern: param) }
               func cast(_ param: Int16)  -> UInt16 { UInt16(bitPattern: param) }
               func cast(_ param: UInt32) -> Int32  {  Int32(bitPattern: param) }
               func cast(_ param: Int32)  -> UInt32 { UInt32(bitPattern: param) }
               func cast(_ param: UInt64) -> Int64  {  Int64(bitPattern: param) }
               func cast(_ param: Int64)  -> UInt64 { UInt64(bitPattern: param) }
               func cast<U: UnsignedInteger>(_ param: U) -> Int { Int(param) }
               func cast<S: SignedInteger>(_ param: S) -> Int { Int(param) }
               func cast<I: BinaryInteger>(_ param: I) -> Bool { param != 0 }
               func cast<I: BinaryInteger>(_ param: Bool) -> I { param ? 1 : 0 }

               func cast(_ param: UnsafeRawPointer) -> OpaquePointer! {
                   return OpaquePointer(param)
               }

               func cast<S, T>(_ param: UnsafeMutablePointer<S>?) -> UnsafeMutablePointer<T>! {
                   return param?.withMemoryRebound(to: T.self, capacity: 1) { $0 }
               }

               func cast<S, T>(_ param: UnsafeMutablePointer<S>?) -> UnsafePointer<T>! {
                   return param?.withMemoryRebound(to: T.self, capacity: 1) { UnsafePointer<T>($0) }
               }

               func cast<S, T>(_ param: UnsafePointer<S>?) -> UnsafePointer<T>! {
                   return param?.withMemoryRebound(to: T.self, capacity: 1) { UnsafePointer<T>($0) }
               }

               func cast<T>(_ param: OpaquePointer?) -> UnsafeMutablePointer<T>! {
                   return UnsafeMutablePointer<T>(param)
               }

               func cast<T>(_ param: OpaquePointer?) -> UnsafePointer<T>! {
                   return UnsafePointer<T>(param)
               }

               func cast(_ param: OpaquePointer?) -> UnsafeMutableRawPointer! {
                   return UnsafeMutableRawPointer(param)
               }

               func cast(_ param: UnsafeRawPointer?) -> UnsafeMutableRawPointer! {
                   return UnsafeMutableRawPointer(mutating: param)
               }

               func cast<T>(_ param: UnsafePointer<T>?) -> OpaquePointer! {
                   return OpaquePointer(param)
               }

               func cast<T>(_ param: UnsafeMutablePointer<T>?) -> OpaquePointer! {
                   return OpaquePointer(param)
               }

               func cast<T>(_ param: UnsafeRawPointer?) -> UnsafeMutablePointer<T>! {
                   return UnsafeMutableRawPointer(mutating: param)?.assumingMemoryBound(to: T.self)
               }

               func cast<T>(_ param: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<T>! {
                   return param?.assumingMemoryBound(to: T.self)
               }

               func cast<T>(_ param: T) -> T { return param }

               extension gboolean {
                   private init(_ b: Bool) { self = b ? gboolean(1) : gboolean(0) }
               }

               func asStringArray(_ param: UnsafePointer<UnsafePointer<CChar>?>) -> [String] {
                   var ptr = param
                   var rv = [String]()
                   while ptr.pointee != nil {
                       rv.append(String(cString: ptr.pointee!))
                       ptr = ptr.successor()
                   }
                   return rv
               }

               func asStringArray<T>(_ param: UnsafePointer<UnsafePointer<CChar>?>, release: ((UnsafePointer<T>?) -> Void)) -> [String] {
                   let rv = asStringArray(param)
                   param.withMemoryRebound(to: T.self, capacity: rv.count) { release(UnsafePointer<T>($0)) }
                   return rv
               }

               """
    }
}


/// Swift extentsion for things
public extension GIR.Thing {
    /// return a name with reserved Ref or Protocol suffixes escaped
    var escapedName: String {
        let na = name.typeEscaped
        return na
    }
}


/// Swift extension for arguments
public extension GIR.CType {
    /// return the, potentially prefixed argument name to use in a method declaration
    var prefixedArgumentName: String {
        let name = argumentName
        let swname = name.camelCase.swift
        let prefixedname = name == swname ? name : (swname + " " + name)
        return prefixedname
    }

    /// return the swift (known) type of the receiver
    var argumentType: String {
        let ct = ctype
        let t = type.isEmpty ? ct : type
        let array = isScalarArray
        let swift = (array ? t.swiftType : t.swift).typeEscaped
        let isPtr  = ct.isPointer
        let record = knownRecord
        let code = "\(array ? "inout [" : "")\(isPtr ? (record.map { $0.protocolName } ?? ct.swiftRepresentationOfCType) : swift)\(array ? "]" : "")"
        return code
    }
}


/// Swift extension for methods
public extension GIR.Method {
    var isDesignatedConstructor: Bool {
        return name == "new"
    }

    /// is this a bare factory method that is not the default constructor
    var isBareFactory: Bool {
        return args.isEmpty && !isDesignatedConstructor
    }

    /// return whether the method is a constructor of the given record
    func isConstructorOf(_ record: GIR.Record?) -> Bool {
        return record != nil && returns.isInstanceOfHierarchy(record!) && !(args.first?.isInstanceOf(record) ?? false)
    }

    /// return whether the method is a factory of the given record
    func isFactoryOf(_ record: GIR.Record?) -> Bool {
        return !isDesignatedConstructor && isConstructorOf(record)
    }
}

/// a pair of getters and setters (both cannot be nil at the same time)
public struct GetterSetterPair {
    let getter: GIR.Method
    let setter: GIR.Method?
}

/// constant for "i" as a code unit
private let iU = "i".utf8.first
/// constant for "_" as a code unit
private let _U = "_".utf8.first!

extension GetterSetterPair {
    /// name of the underlying property for a getter / setter pair
    var name: String {
        let n = getter.name.utf8 
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
        let u = $0.name.utf8
        let v = $1.name.utf8
        let o = u.first == iU ? 0 : 4;  // no offset for "is_..."
        let p = v.first == iU ? 0 : 4;
        let a = u[u.index(u.startIndex, offsetBy: o)..<u.endIndex]
        let b = v[v.index(v.startIndex, offsetBy: p)..<v.endIndex]
        return String(Substring(a)) <= String(Substring(b))
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
    var swift: String { return name.swift }

    /// swift protocol name for this record
    var protocolName: String { return swift.protocolName }

    /// swift struct name for this record
    var structName: String { return swift + "Ref" }

    /// swift class name for this record
    var className: String { return swift }
}


/// GIR extension for Strings
extension String {
    /// indicates whether the receiver is a known type
    public var isKnownType: Bool { return GIR.KnownTypes[self] != nil }

    /// swift protocol name for a given string
    var protocolName: String { return self + "Protocol" }
}


/// SwiftDoc representation of comments
public func commentCode(_ thing: GIR.Thing, indentation: String = "") -> String {
    let prefix = indentation + "/// "
    let comment = thing.comment
    let documentation = gtkDoc2SwiftDoc(comment, linePrefix: prefix)
    return documentation
}

/// Swift representation of deprecation
public func deprecatedCode(_ thing: GIR.Thing, indentation: String) -> String? {
    return thing.deprecated.map { (s: String) -> String in
        let prefix = indentation + "/// "
        return s.isEmpty ? "" : s.reduce(prefix) {
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
        swiftCode(m, indentation + "static let \(m.name.swiftName) = \(m.ctype.swift) /* \(m.value) */", indentation: indentation)
    }
}


/// Swift code type definition of a bitfield
public func bitfieldTypeHead(_ bf: GIR.Bitfield, enumRawType: String = "UInt32", indentation: String) -> String {
    let bftype = bf.type.swift
    return swiftCode(bf, "public struct \(bf.escapedName.swift): OptionSet {\n" + indentation +
        "/// The corresponding value of the raw type\n" + indentation +
        "public var rawValue: \(enumRawType) = 0\n" + indentation +
        "/// The equivalent raw Int value\n" + indentation +
        "public var intValue: Int { get { Int(rawValue) } set { rawValue = \(enumRawType)(newValue) } }\n" + indentation +
        "/// The equivalent raw `gint` value\n" + indentation +
        "public var int: gint { get { gint(rawValue) } set { rawValue = \(enumRawType)(newValue) } }\n" + indentation +
        "/// The equivalent underlying `\(bftype)` enum value\n" + indentation +
        "public var value: \(bftype) { get { \(bftype)(rawValue: cast(rawValue)) } set { rawValue = \(enumRawType)(newValue.rawValue) } }\n\n" + indentation +
        "/// Creates a new instance with the specified raw value\n" + indentation +
        "public init(rawValue: \(enumRawType)) { self.rawValue = rawValue }\n" + indentation +
        "/// Creates a new instance with the specified `\(bftype)` enum value\n" + indentation +
        "public init(_ enumValue: \(bftype)) { self.rawValue = \(enumRawType)(enumValue.rawValue) }\n" + indentation +
        "/// Creates a new instance with the specified Int value\n" + indentation +
        "public init(_ intValue: Int)   { self.rawValue = \(enumRawType)(intValue)  }\n" + indentation +
        "/// Creates a new instance with the specified `gint` value\n" + indentation +
        "public init(_ gintValue: gint) { self.rawValue = \(enumRawType)(gintValue) }\n\n"
    )
}

/// Swift code representation of an enum
public func swiftCode(_ bf: GIR.Bitfield) -> String {
    let indent = "    "
    let head = bitfieldTypeHead(bf, indentation: indent)
    let names = Set(bf.members.map(\.name.camelCase.swift))
    let deprecated = bf.members.lazy.filter { !names.contains($0.name.swiftName) }
    let code = head + bf.members.map(bitfieldValueCode(bf, indent)).joined(separator: "\n") + "\n\n"
                    + deprecated.map(bitfieldDeprecated(bf, indent)).joined(separator: "\n") + "\n}"
    return code
}

/// Swift code representation of a bit field value
public func bitfieldValueCode(_ bf: GIR.Bitfield, _ indentation: String) -> (GIR.Bitfield.Member) -> String {
    let type = bf.escapedName.swift
    return { (m: GIR.Enumeration.Member) -> String in
        swiftCode(m, indentation + "public static let \(m.name.camelCase.swift) = \(type)(\(m.value)) /* \(m.ctype.swift) */", indentation: indentation)
    }
}


/// Deprecated Swift code representation of a bit field value
public func bitfieldDeprecated(_ bf: GIR.Bitfield, _ indentation: String) -> (GIR.Bitfield.Member) -> String {
    let type = bf.escapedName.swift
    return { (m: GIR.Enumeration.Member) -> String in
        swiftCode(m, indentation + "@available(*, deprecated) public static let \(m.name.swiftName) = \(type)(\(m.value)) /* \(m.ctype.swift) */", indentation: indentation)
    }
}


/// Swift protocol representation of a record/class as a wrapper of a pointer
public func recordProtocolCode(_ e: GIR.Record, parent: String, indentation: String = "    ", ptr: String = "ptr") -> String {
    let p = (parent.isEmpty ? "" : ": \(parent)")
    let ctype = e.ctype.isEmpty ? e.type.swift : e.ctype.swift
    let documentation = commentCode(e)
    let code = "// MARK: - \(e.name) \(e.kind)\n\n" +
        "/// The `\(e.protocolName)` protocol exposes the methods and properties of an underlying `\(ctype)` instance.\n" +
        "/// The default implementation of these can be found in the protocol extension below.\n" +
        "/// For a concrete class that implements these methods and properties, see `\(e.className)`.\n" +
        "/// Alternatively, use `\(e.structName)` as a lighweight, `unowned` reference if you already have an instance you just want to use.\n///\n" +
            documentation + "\n" +
        "public protocol \(e.protocolName)\(p) {\n" + indentation +
            "/// Untyped pointer to the underlying `\(ctype)` instance.\n" + indentation +
            "var ptr: UnsafeMutableRawPointer { get }\n\n" + indentation +
            "/// Typed pointer to the underlying `\(ctype)` instance.\n" + indentation +
            "var \(ptr): UnsafeMutablePointer<\(ctype)> { get }\n" +
        "}\n\n"
    return code
}


/// Default implementation for record methods as protocol extension
public func recordProtocolExtensionCode(_ globalFunctions: [GIR.Function], _ e: GIR.Record, indentation: String = "    ", ptr ptrName: String = "ptr") -> String {
    let vcode = computedPropertyCode(indentation, record: e, publicDesignation: "", ptr: ptrName)
    let allFunctions = e.functions + globalFunctions
    let instanceMethods: [GIR.Method] = allFunctions.filter {
        let fun = $0
        return fun.args.lazy.filter({ (arg: GIR.Argument) -> Bool in
            arg.isInstanceOf(e)
        }).first != nil
    }
    let allMethods: [GIR.Method] = e.methods + instanceMethods
    let gsPairs = getterSetterPairs(for: allMethods)
    let propertyNames = Set(gsPairs.map { $0.name })
    let mcode = methodCode(indentation, record: e, avoiding: propertyNames, publicDesignation: "", ptr: ptrName)
    let fcode = fieldCode(indentation, record: e, avoiding: propertyNames, publicDesignation: "", ptr: ptrName)
    let methods = allMethods.filter { method in
        !method.name.hasPrefix("is_") || !gsPairs.contains { $0.getter === method } }
    let ctype = e.ctype.isEmpty ? e.type.swift : e.ctype.swift
    let code = "public extension \(e.protocolName) {\n" + indentation +
        "/// Return the stored, untyped pointer as a typed pointer to the `\(ctype)` instance.\n" + indentation +
        "var \(ptrName): UnsafeMutablePointer<\(ctype)> { return ptr.assumingMemoryBound(to: \(ctype).self) }\n\n" +
        methods.map(mcode).joined(separator: "\n") +
        gsPairs.map(vcode).joined(separator: "\n") + "\n" +
        e.fields.map(fcode).joined(separator: "\n") +
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
public func methodCode(_ indentation: String, initialIndentation: String? = nil, record: GIR.Record? = nil, avoiding existingNames: Set<String> = [], publicDesignation: String = "public ", convertName: @escaping (String) -> String = { $0.camelCase }, ptr ptrName: String = "ptr") -> (GIR.Method) -> String {
    let indent = initialIndentation ?? indentation
    let doubleIndent = indent + indentation
    let call = callCode(doubleIndent, record, ptr: ptrName)
    let returnDeclaration = returnDeclarationCode()
    let ret = returnCode(indentation, ptr: ptrName)
//    let rtypeF = returnTypeCode()
    return { (method: GIR.Method) -> String in
        let rawName = method.name.isEmpty ? method.cname : method.name
        let potentiallyClashingName = convertName(rawName)
        let name: String
        if existingNames.contains(potentiallyClashingName) {
            name = "get" + potentiallyClashingName.capitalized
        } else { name = potentiallyClashingName }
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
        if let firstParamName = params.first?.split(separator: " ").first?.split(separator: ":").first?.capitalized {
            fname = name.stringByRemoving(suffix: firstParamName) ?? name
        } else {
            fname = name
        }
        let deprecated = method.deprecated != nil ? "@available(*, deprecated) " : ""
        let code = swiftCode(method, indent + "\(deprecated)\(publicDesignation)func \(fname.swift)(" +
            funcParam + ")\(returnDeclaration(method)) {\n" +
                doubleIndent + call(method) +
                indent       + ret(method)  + indent +
        "}\n", indentation: indent)
        return code
    }
}


/// Swift code for computed properties
public func computedPropertyCode(_ indentation: String, record: GIR.Record, avoiding existingNames: Set<String> = [], publicDesignation: String = "public ", ptr ptrName: String = "ptr") -> (GetterSetterPair) -> String {
    let doubleIndent = indentation + indentation
    let gcall = callCode(doubleIndent, record, ptr: ptrName)
    let scall = callSetter(doubleIndent, record, ptr: ptrName)
    let ret = returnCode(doubleIndent, ptr: ptrName)
    return { (pair: GetterSetterPair) -> String in
        let name: String
        if existingNames.contains(pair.name) {
            name = "_" + pair.name
        } else { name = pair.name.swiftQuoted }
        guard !GIR.Blacklist.contains(name) else {
            return "\n\(indentation)// *** \(name)() causes a syntax error and is therefore not available!\n\n"
        }
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
        let idiomaticType = type.idiomatic
        let property: GIR.CType
        if let prop = record.properties.filter({ $0.name.swiftQuoted == name }).first {
            property = prop
        } else {
            property = gs
        }
        let varDecl = swiftCode(property, indentation + "\(publicDesignation)var \(name): \(idiomaticType) {\n", indentation: indentation)
        let deprecated = getter.deprecated != nil ? "@available(*, deprecated) " : ""
        let getterCode = swiftCode(getter, doubleIndent + "\(deprecated)get {\n" +
            doubleIndent + indentation + gcall(getter) +
            indentation  + ret(getter) + doubleIndent +
            "}\n", indentation: doubleIndent)
        let setterCode: String
        if let setter = pair.setter {
            let deprecated = setter.deprecated != nil ? "@available(*, deprecated) " : ""
            setterCode = swiftCode(setter, doubleIndent + "\(deprecated)nonmutating set {\n" +
                doubleIndent + indentation + scall(setter) +
                doubleIndent + "}\n", indentation: doubleIndent)
        } else {
            setterCode = ""
        }
        let varEnd = indentation + "}\n"
        return varDecl + getterCode + setterCode + varEnd
    }
}


/// Swift code for field properties
public func fieldCode(_ indentation: String, record: GIR.Record, avoiding existingNames: Set<String> = [], publicDesignation: String = "public ", ptr: String = "_ptr") -> (GIR.Field) -> String {
    let doubleIndent = indentation + indentation
    let ret = instanceReturnCode(doubleIndent, ptr: "rv", castVar: "rv")
    return { (field: GIR.Field) -> String in
        let name = field.name
        let potentiallyClashingName = name.camelCase
        let swname: String
        if existingNames.contains(potentiallyClashingName) {
            let underscored = "_" + potentiallyClashingName
            if existingNames.contains(underscored) {
                swname = underscored + "_"
            } else {
                swname = underscored
            }
        } else { swname = field.name.swiftQuoted }
        guard !GIR.Blacklist.contains(name) && !GIR.Blacklist.contains(swname) else {
            return "\n\(indentation)// *** \(name)() causes a syntax error and is therefore not available!\n\n"
        }
        guard !field.isPrivate else { return indentation + "// var \(swname) is unavailable because \(name) is private\n" }
        let containedType = field.containedTypes.first ?? field
        let pointee = ptr + ".pointee." + name
        let scall = instanceSetter(doubleIndent, record, target: pointee, ptr: "newValue")
        guard field.isReadable || field.isWritable else { return indentation + "// var \(name) is unavailable because it is neigher readable nor writable\n" }
        guard !field.isVoid else { return indentation + "// var \(swname) is unavailable because \(name) is void\n" }
        let type = typeCastTuple(containedType.ctype, field.ctype.swiftVerbatim, varName: pointee, castVar: pointee, convertToSwiftTypes: false).swift
        let idiomaticType = type.idiomatic
        let varDecl = swiftCode(field, indentation + "\(publicDesignation)var \(swname): \(idiomaticType) {\n", indentation: indentation)
        let deprecated = field.deprecated != nil ? "@available(*, deprecated) " : ""
        let getterCode: String
        if field.isReadable {
            getterCode = swiftCode(field, doubleIndent + "\(deprecated)get {\n" + doubleIndent +
            indentation + "let rv: \(idiomaticType) = cast(" + pointee + ")\n" +
            indentation + ret(field) + doubleIndent +
            "}\n", indentation: doubleIndent)
        } else {
            getterCode = ""
        }
        let setterCode: String
        if field.isWritable {
            setterCode = swiftCode(field, doubleIndent + "\(deprecated) set {\n" +
                doubleIndent + indentation + scall(field) + "\n" +
                doubleIndent + "}\n", indentation: doubleIndent)
        } else {
            setterCode = ""
        }
        let varEnd = indentation + "}\n"
        return varDecl + getterCode + setterCode + varEnd
    }
}




/// Swift code for convenience constructors
public func convenienceConstructorCode(_ typeName: String, indentation: String, convenience: String = "", override ovr: String = "", publicDesignation: String = "public ", factory: Bool = false, hasParent: Bool = false, convertName: @escaping (String) -> String = { $0.camelCase }) -> (GIR.Record) -> (GIR.Method) -> String {
    let isConv = !convenience.isEmpty
    let conv =  isConv ? "\(convenience) " : ""
    return { (record: GIR.Record) -> (GIR.Method) -> String in
        let doubleIndent = indentation + indentation
        let call = callCode(doubleIndent)
        let returnDeclaration = returnDeclarationCode((typeName: typeName, record: record, isConstructor: !factory))
        let ret = returnCode(indentation, (typeName: typeName, record: record, isConstructor: !factory, isConvenience: isConv), hasParent: hasParent)
        return { (method: GIR.Method) -> String in
            let rawName = method.name.isEmpty ? method.cname : method.name
            let rawUTF = rawName.utf8
            let firstArgName = method.args.first?.name
            let nameWithoutPostFix: String
            if let f = firstArgName, rawUTF.count > f.utf8.count + 1 && rawName.hasSuffix(f) {
                let truncated = rawUTF[rawUTF.startIndex..<rawUTF.index(rawUTF.endIndex, offsetBy: -f.utf8.count)]
                if truncated.last == _U {
                    let noUnderscore = rawUTF[rawUTF.startIndex..<rawUTF.index(rawUTF.endIndex, offsetBy: -(f.utf8.count+1))]
                    nameWithoutPostFix = String(Substring(noUnderscore))
                } else {
                    nameWithoutPostFix = String(Substring(truncated))
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
            let isOverride = GIR.overrides.contains(method.cname)
            let override = record.inheritedMethods.filter { $0.name == rawName }.first != nil
            let fullname = override ? convertName((method.cname.afterFirst() ?? (record.name + nameWithoutPostFix.capitalized))) : name
            let consPrefix = constructorPrefix(method)
            let fname: String
            if let prefix = consPrefix?.capitalized {
                fname = fullname.stringByRemoving(suffix: prefix) ?? fullname
            } else {
                fname = fullname
            }
            let p: String? = consPrefix == firstArgName?.swift ? nil : consPrefix
            let fact = factory ? "static func \(fname.swift)(" : "\(isOverride ? ovr : conv)init("
            let code = swiftCode(method, indentation + "\(deprecated)\(publicDesignation)\(fact)" +
                constructorParam(method, prefix: p) + ")\(returnDeclaration(method)) {\n" +
                    doubleIndent + call(method) +
                    indentation  + ret(method)  + indentation +
                "}\n", indentation: indentation)
            return code
        }
    }
}


/// Return the return type of a method, 
public func returnTypeCode(_ tr: (typeName: String, record: GIR.Record, isConstructor: Bool)? = nil, useIdiomaticSwift beIdiomatic: Bool = true) -> (GIR.Method) -> String? {
    return { method in
        let rv = method.returns
        guard !(rv.isVoid || (tr != nil && tr!.isConstructor)) else { return nil }
        let returnType: String
        if tr != nil && rv.isInstanceOfHierarchy((tr?.record)!)  {
            returnType = tr!.typeName + "!"
        } else {
            let swiftEquivalent = rv.type.swift
            let swiftType = beIdiomatic ? swiftEquivalent.idiomatic : swiftEquivalent
            let typeTuple = typeCastTuple(rv.ctype, swiftType, useIdiomaticSwift: beIdiomatic)
            let rtSwift = typeTuple.swift
            let rt = beIdiomatic ? rtSwift.idiomatic : rtSwift
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
public func returnCode(_ indentation: String, _ tr: (typeName: String, record: GIR.Record, isConstructor: Bool, isConvenience: Bool)? = nil,
                       ptr: String = "ptr", hasParent: Bool = false, useIdiomaticSwift beIdiomatic: Bool = true, noCast: Bool = false) -> (GIR.Method) -> String {
    returnCode(indentation, tr, ptr: ptr, hasParent: hasParent, useIdiomaticSwift: beIdiomatic, noCast: noCast) { $0.returns }
}

/// Return code for instances (e.g. fields)
public func instanceReturnCode(_ indentation: String, _ tr: (typeName: String, record: GIR.Record, isConstructor: Bool, isConvenience: Bool)? = nil,
                               ptr: String = "ptr", castVar: String = "rv", hasParent: Bool = false, forceCast doForce: Bool = true, noCast: Bool = true,
                               convertToSwiftTypes doConvert: Bool = false, useIdiomaticSwift beIdiomatic: Bool = true) -> (GIR.CType) -> String {
    returnCode(indentation, tr, ptr: ptr, rv: castVar, hasParent: hasParent, forceCast: doForce, convertToSwiftTypes: doConvert, useIdiomaticSwift: beIdiomatic, noCast: noCast) { $0 }
}

/// Generic return code for methods/types
public func returnCode<T>(_ indentation: String, _ tr: (typeName: String, record: GIR.Record, isConstructor: Bool, isConvenience: Bool)? = nil,
                          ptr: String = "ptr", rv: String = "rv", hasParent: Bool = false, forceCast doForce: Bool = false,
                          convertToSwiftTypes doConvert: Bool = true, useIdiomaticSwift beIdiomatic: Bool = true, noCast: Bool = true,
                          extract: @escaping (T) -> GIR.CType) -> (T) -> String {
    return { (param: T) -> String in
        let field = extract(param)
        guard !field.isVoid else { return "\n" }
        let isInstance = tr?.record != nil && field.isInstanceOfHierarchy((tr?.record)!)
        let swiftType = doConvert ? field.type.swift : field.type.swiftVerbatim
        let cast2swift = typeCastTuple(field.ctype, swiftType, varName: rv, castVar: rv, forceCast: doForce || isInstance, convertToSwiftTypes: doConvert, useIdiomaticSwift: beIdiomatic, noCast: noCast).toSwift
        guard isInstance, let tr = tr else { return indentation + "return \(cast2swift)\n" }
        let (cons, cast, end) = tr.isConstructor ?
            (tr.isConvenience ? ("self.init", cast2swift, "") : (hasParent ?
                ("super.init", cast2swift, "") : ("\(ptr) = UnsafeMutableRawPointer", cast2swift, ""))) :
            ("return rv.map { \(tr.typeName)", "cast($0)", " }")
        if tr.isConvenience || !tr.isConstructor {
            return indentation + "\(cons)(\(cast))\(end)\n"
        } else if tr.isConstructor {
            return indentation + "\(cons)(\(cast))\(end)\n"
        } else {
            return indentation + "self.init(\(cast2swift))\n"
        }
    }
}


/// Swift code for calling the underlying function and assigning the raw return value
public func callCode(_ indentation: String, _ record: GIR.Record? = nil, ptr: String = "ptr", rvVar: String = "rv", useIdiomaticSwift: Bool = true) -> (GIR.Method) -> String {
    var hadInstance = false
    let toSwift: (GIR.Argument) -> String = { arg in
        let name = arg.nonClashingName
        guard !arg.isScalarArray else { return "&" + name }
        let instance = !hadInstance && (arg.instance || arg.isInstanceOf(record))
        if instance { hadInstance = true }
        let types = typeCastTuple(arg.ctype, arg.type.swift, varName: instance ? ptr : (name + (arg.isKnownRecord ? ".ptr" : "") + (!arg.isAnyKindOfPointer && arg.isKnownBitfield ? ".value" : "")))
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
        let rvType: String
        let rvSType = rv.type.swift
        if useIdiomaticSwift {
            let rvIType = rvSType.idiomatic
            rvType = rvIType == rvSType ? "" : rvIType
        } else {
            rvType = rvSType
        }
        let errCode = ( throwsError ? "var error: Optional<UnsafeMutablePointer<\(gerror)>> = nil\n" + indentation : "")
        let varCode = isVoid || rvVar.isEmpty ? "" : "let \(rvVar)\(rvType.isEmpty ?  "" : ": \(rvType)") = "
        let callCode = ( rvType.isEmpty ? "" : "cast(" ) + method.cname.swift +
            "(\(args.map(toSwift).joined(separator: ", "))"
        let throwCode = throwsError ? ((n == 0 ? "" : ", ") + "&error)\(rvType.isEmpty ? "" : ")")\n" +
            indentation + "if let error = error { throw ErrorType(error) }\n") : ")\(rvType.isEmpty ? "" : ")")\n"
        let code = errCode + varCode + callCode + throwCode
        return code
    }
}


/// Swift code for calling the underlying setter function and assigning the raw return value
public func callSetter(_ indentation: String, _ record: GIR.Record? = nil, ptr ptrName: String = "ptr") -> (GIR.Method) -> String {
    let toSwift = convertSetterArgumentToSwiftFor(record, ptr: ptrName)
    return { method in
        let args = method.args // not .lazy
        let code = ( method.returns.isVoid ? "" : "let _ = " ) +
            "\(method.cname.swift)(\(args.map(toSwift).joined(separator: ", ")))\n"
        return code
    }
}

/// Swift code for assigning the raw return value
public func instanceSetter(_ indentation: String, _ record: GIR.Record? = nil, target: String = "ptr", ptr parameterName: String = "newValue", castVar: String = "newValue", convertToSwiftTypes doConvert: Bool = false) -> (GIR.CType) -> String {
    return { field in
        guard !field.isVoid else { return "// \(field.name) is Void\n" }
        let containedType = field.containedTypes.first ?? field
        let ftype = field.type.isEmpty ? field.ctype : field.type
        let swiftType = doConvert ? ftype.swift : ftype.swiftVerbatim
        let types = typeCastTuple(containedType.ctype, swiftType, varName: parameterName, castVar: castVar, convertToSwiftTypes: doConvert)
        let cType = types.toC
        let code = cType == castVar || cType.hasSuffix("ptr") ? "cast(\(cType))" : cType
        return "\(target) = \(code)"
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
            let s = name.index(name.startIndex, offsetBy: prefix.count)
            let e = name.endIndex
            return String(name[s..<e]).swift
        }
        if let suffix = (["_newv", "_new"].lazy.filter { name.hasSuffix($0) }.first) {
            let s = name.startIndex
            let e = name.index(name.endIndex, offsetBy: -suffix.count)
            return String(name[s..<e]).swift
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
public func toSwift(_ arg: GIR.Argument, ptr: String = "ptr") -> String {
    let types = typeCastTuple(arg.ctype, arg.type.swift, varName: arg.instance ? ptr : (arg.nonClashingName + (arg.isKnownRecord ? ".ptr" : "")))
    let param = types.toC.hasSuffix("ptr") ? "cast(\(types.toC))" : types.toC
    return param
}


/// Swift code for passing a setter to a method of a record / class
public func convertSetterArgumentToSwiftFor(_ record: GIR.Record?, ptr: String = "ptr") -> (GIR.Argument) -> String {
    return { arg in
        let name = arg.nonClashingName
        guard !arg.isScalarArray else { return "&" + name }
        let types = typeCastTuple(arg.ctype, arg.type.swift, varName: arg.instance || arg.isInstanceOf(record) ? ptr : ("newValue"))
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
public func recordStructCode(_ e: GIR.Record, indentation: String = "    ", ptr: String = "ptr") -> String {
    let structType = "\(e.name)Ref"
    let protocolName = e.protocolName
//    let parent = e.parentType
//    let root = parent?.rootType
//    let p = parent ?? e
//    let r = root ?? p
    let ctype = e.ctype.isEmpty ? e.type.swift : e.ctype.swift
//    let rtype = r.ctype.isEmpty ? r.type.swift : r.ctype.swift
    let ccode = convenienceConstructorCode(structType, indentation: indentation, publicDesignation: "")(e)
    let fcode = convenienceConstructorCode(structType, indentation: indentation, publicDesignation: "", factory: true)(e)
    let constructors = e.constructors.filter { $0.isConstructorOf(e) && !$0.isBareFactory }
    let allFunctions: [GIR.Method] = e.methods + e.functions
    let factories: [GIR.Method] = (e.constructors + allFunctions).filter { $0.isFactoryOf(e) }
    let documentation = commentCode(e)
    let code = "/// The `\(structType)` type acts as a lightweight Swift reference to an underlying `\(ctype)` instance.\n" +
    "/// It exposes methods that can operate on this data type through `\(protocolName)` conformance.\n" +
    "/// Use `\(structType)` only as an `unowned` reference to an existing `\(ctype)` instance.\n///\n" +
        documentation + "\n" +
    "public struct \(structType): \(protocolName) {\n" + indentation +
        "/// Untyped pointer to the underlying `\(ctype)` instance.\n" + indentation +
        "/// For type-safe access, use the generated, typed pointer `\(ptr)` property instead.\n" + indentation +
        "public let ptr: UnsafeMutableRawPointer\n" +
    "}\n\n" +
    "public extension \(structType) {\n" + indentation +
        "/// Designated initialiser from the underlying `C` data type\n" + indentation +
        "init(_ p: UnsafeMutablePointer<\(ctype)>) {\n" + indentation + indentation +
            "ptr = UnsafeMutableRawPointer(p)" + indentation +
        "}\n\n" + indentation +
        "/// Reference intialiser for a related type that implements `\(protocolName)`\n" + indentation +
        "init<T: \(protocolName)>(_ other: T) {\n" + indentation + indentation +
            "ptr = other.ptr\n" + indentation +
        "}\n\n" + indentation +
        "/// Unsafe typed initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "init<T>(cPointer: UnsafeMutablePointer<T>) {\n" + indentation + indentation +
            "ptr = UnsafeMutableRawPointer(cPointer)\n" + indentation +
        "}\n\n" + indentation +
        "/// Unsafe typed initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "init<T>(constPointer: UnsafePointer<T>) {\n" + indentation + indentation +
            "ptr = UnsafeMutableRawPointer(mutating: UnsafeRawPointer(constPointer))\n" + indentation +
        "}\n\n" + indentation +
        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "init(raw: UnsafeRawPointer) {\n" + indentation + indentation +
            "ptr = UnsafeMutableRawPointer(mutating: raw)\n" + indentation +
        "}\n\n" + indentation +
        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "init(raw: UnsafeMutableRawPointer) {\n" + indentation + indentation +
            "ptr = raw\n" + indentation +
        "}\n\n" + indentation +
        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "init(opaquePointer: OpaquePointer) {\n" + indentation + indentation +
            "ptr = UnsafeMutableRawPointer(opaquePointer)\n" + indentation +
        "}\n\n" + indentation +
        constructors.map(ccode).joined(separator: "\n") +
        factories.map(fcode).joined(separator: "\n") +
    "}\n\n"

    return code
}


/// Swift struct representation of a record/class as a wrapper of a pointer
public func recordClassCode(_ e: GIR.Record, parent: String, indentation: String = "    ", ptr: String = "ptr") -> String {
    let doubleIndentation = indentation + indentation
    let tripleIndentation = indentation + doubleIndentation
    let classType = e.name.swift
    let instance = classType.deCapitalised
    let protocolName = e.protocolName
    let parentType = e.parentType
    let hasParent = parentType != nil
    let ctype = e.ctype.isEmpty ? e.type.swift : e.ctype.swift
    let scode = signalNameCode(indentation: indentation)
    let ncode = signalNameCode(indentation: indentation, prefixes: ("notify", "notify::"))
    let ccode = convenienceConstructorCode(classType, indentation: indentation, override: "override ", hasParent: hasParent)(e)
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
    let documentation = commentCode(e)
    let code1 = "/// The `\(classType)` type acts as a\(e.ref == nil ? "n" : " reference-counted") owner of an underlying `\(ctype)` instance.\n" +
    "/// It provides the methods that can operate on this data type through `\(protocolName)` conformance.\n" +
    "/// Use `\(classType)` as a strong reference or owner of a `\(ctype)` instance.\n///\n" +
        documentation + "\n" +
    "open class \(classType): \(p)\(protocolName) {\n" + indentation +
        (hasParent ? "" : (
            "/// Untyped pointer to the underlying `\(ctype)` instance.\n" + indentation +
            "/// For type-safe access, use the generated, typed pointer `\(ptr)` property instead.\n" + indentation +
            "public let ptr: UnsafeMutableRawPointer\n\n" + indentation)
        ) +
        "/// Designated initialiser from the underlying `C` data type.\n" + indentation +
        "/// This creates an instance without performing an unbalanced retain\n" + indentation +
        "/// i.e., ownership is transferred to the `\(classType)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n" + indentation +
        "public init(_ op: UnsafeMutablePointer<\(ctype)>) {\n" + indentation + indentation +
            (hasParent ? "super.init(cast(op))\n" : "ptr = UnsafeMutableRawPointer(op)\n") + indentation +
        "}\n\n" + (indentation +

        "/// Designated initialiser from the underlying `C` data type.\n" + indentation +
        "/// \(e.ref == nil ? "`\(e.ctype.swift)` does not allow reference counting, so despite the name no actual retaining will occur." : "Will retain `\(e.ctype.swift)`.")\n" + indentation +
        "/// i.e., ownership is transferred to the `\(classType)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n") + (indentation +
        "public init(retaining op: UnsafeMutablePointer<\(ctype)>) {\n" + doubleIndentation +
            (hasParent ?
                "super.init(retaining: cast(op))\n" :
                "ptr = UnsafeMutableRawPointer(op)\n" + doubleIndentation +
                "\(retain)(cast(\(ptr)))\n") + indentation +
        "}\n\n") + (indentation +

        "/// Reference intialiser for a related type that implements `\(protocolName)`\n" + indentation +
        "/// \(e.ref == nil ? "`\(e.ctype.swift)` does not allow reference counting." : "Will retain `\(e.ctype.swift)`.")\n" + indentation +
        "/// - Parameter other: an instance of a related type that implements `\(protocolName)`\n" + indentation +
        "public init<T: \(e.protocolName)>(\(hasParent ? instance : "_") other: T) {\n" + doubleIndentation +
            (hasParent ? "super.init(retaining: cast(other.\(ptr)))\n" :
            "ptr = UnsafeMutableRawPointer(other.\(ptr))\n" + doubleIndentation +
            "\(retain)(cast(\(ptr)))\n") + indentation +
        "}\n\n") + (hasParent ? "" : (indentation +

        "/// \(e.unref == nil ? "Do-nothing destructor for`\(e.ctype.swift)`." : "Releases the underlying `\(e.ctype.swift)` instance using `\(e.unref?.cname ?? "unref")`.")\n" + indentation +
        "deinit {\n" + indentation + indentation +
            "\(release)(cast(\(ptr)))\n" + indentation +
        "}\n\n")) + ((indentation +

        "/// Unsafe typed initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter cPointer: pointer to the underlying object\n" + indentation +
        (hasParent ? "override " : "") +
        "public init<T>(cPointer p: UnsafeMutablePointer<T>) {\n" + doubleIndentation +
            (hasParent ? "super.init(cPointer: p)\n" : "ptr = UnsafeMutableRawPointer(p)\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe typed, retaining initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter cPointer: pointer to the underlying object\n" + indentation +
        (hasParent ? "override " : "") +
        "public init<T>(retainingCPointer cPointer: UnsafeMutablePointer<T>) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingCPointer: cPointer)\n" :
            "ptr = UnsafeMutableRawPointer(cPointer)\n" + doubleIndentation +
            "\(retain)(cast(\(ptr)))\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter p: raw pointer to the underlying object\n" + indentation +
        (hasParent ? "override " : "") +
        "public init(raw p: UnsafeRawPointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(raw: p)\n" : "ptr = UnsafeMutableRawPointer(mutating: p)\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped, retaining initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        (hasParent ? "override " : "") +
        "public init(retainingRaw raw: UnsafeRawPointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingRaw: raw)\n" :
            "ptr = UnsafeMutableRawPointer(mutating: raw)\n" + doubleIndentation +
            "\(retain)(cast(\(ptr)))\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter p: mutable raw pointer to the underlying object\n" + indentation +
        (hasParent ? "override " : "") +
        "public init(raw p: UnsafeMutableRawPointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(raw: p)\n" : "ptr = p\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped, retaining initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter raw: mutable raw pointer to the underlying object\n" + indentation +
        (hasParent ? "override " : "") +
        "public init(retainingRaw raw: UnsafeMutableRawPointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingRaw: raw)\n" :
            "ptr = raw\n" + doubleIndentation +
            "\(retain)(cast(\(ptr)))\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter p: opaque pointer to the underlying object\n" + indentation +
        (hasParent ? "override " : "") +
        "public init(opaquePointer p: OpaquePointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(opaquePointer: p)\n" : "ptr = UnsafeMutableRawPointer(p)\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped, retaining initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter p: opaque pointer to the underlying object\n" + indentation +
        (hasParent ? "override " : "") +
        "public init(retainingOpaquePointer p: OpaquePointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingOpaquePointer: p)\n" :
            "ptr = UnsafeMutableRawPointer(p)\n" + doubleIndentation +
            "\(retain)(cast(\(ptr)))\n") + indentation +
        "}\n\n"))
    let code2 = constructors.map(ccode).joined(separator: "\n") + "\n" +
        factories.map(fcode).joined(separator: "\n") + "\n" +
    "}\n\n"
    let code3 = String(noProperties ? "// MARK: - no \(classType) properties\n" : "public enum \(classType)PropertyName: String, PropertyNameProtocol {\n") +
//        "public typealias Class = \(protocolName)\n") +
        properties.map(scode).joined(separator: "\n") + "\n" +
    (noProperties ? "" : ("}\n\npublic extension \(protocolName) {\n" + indentation +
        "/// Bind a `\(classType)PropertyName` source property to a given target object.\n" + indentation +
        "/// - Parameter source_property: the source property to bind\n" + indentation +
        "/// - Parameter target: the target object to bind to\n" + indentation +
        "/// - Parameter target_property: the target property to bind to\n" + indentation +
        "/// - Parameter flags: the flags to pass to the `Binding`\n" + indentation +
        "/// - Parameter transform_from: `ValueTransformer` to use for forward transformation\n" + indentation +
        "/// - Parameter transform_to: `ValueTransformer` to use for backwards transformation\n" + indentation +
        "/// - Returns: binding reference or `nil` in case of an error\n" + indentation +
        "@discardableResult func bind<Q: PropertyNameProtocol, T: ObjectProtocol>(property source_property: \(classType)PropertyName, to target: T, _ target_property: Q, flags f: BindingFlags = .default_, transformFrom transform_from: @escaping GLibObject.ValueTransformer = { $0.transform(destValue: $1) }, transformTo transform_to: @escaping GLibObject.ValueTransformer = { $0.transform(destValue: $1) }) -> BindingRef! {\n" + doubleIndentation +
            "func _bind(_ source: UnsafePointer<gchar>, to t: T, _ target_property: UnsafePointer<gchar>, flags f: BindingFlags = .default_, holder: BindingClosureHolder, transformFrom transform_from: @convention(c) @escaping (gpointer, gpointer, gpointer, gpointer) -> gboolean, transformTo transform_to: @convention(c) @escaping (gpointer, gpointer, gpointer, gpointer) -> gboolean) -> BindingRef! {\n" + tripleIndentation +
                "let holder = UnsafeMutableRawPointer(Unmanaged.passRetained(holder).toOpaque())\n" + tripleIndentation +
                "let from = unsafeBitCast(transform_from, to: BindingTransformFunc.self)\n" + tripleIndentation +
                "let to   = unsafeBitCast(transform_to,   to: BindingTransformFunc.self)\n" + tripleIndentation +
                "let rv = GLibObject.ObjectRef(cast(\(ptr))).bindPropertyFull(sourceProperty: source, target: t, targetProperty: target_property, flags: f, transformTo: to, transformFrom: from, userData: holder) {\n" + tripleIndentation + indentation +
                    "if let swift = UnsafeRawPointer($0) {\n" + tripleIndentation + doubleIndentation +
                        "let holder = Unmanaged<GLibObject.SignalHandlerClosureHolder>.fromOpaque(swift)\n" + tripleIndentation + doubleIndentation +
                        "holder.release()\n" + tripleIndentation + indentation +
                    "}\n" + tripleIndentation +
                "}\n" + tripleIndentation +
                "return rv.map { BindingRef(cast($0)) }\n" + doubleIndentation +
            "}\n\n" + doubleIndentation +
            "let rv = _bind(source_property.name, to: target, target_property.name, flags: f, holder: BindingClosureHolder(transform_from, transform_to), transformFrom: {\n" + tripleIndentation +
                "let ptr = UnsafeRawPointer($3)\n" + tripleIndentation +
                "let holder = Unmanaged<BindingClosureHolder>.fromOpaque(ptr).takeUnretainedValue()\n" + tripleIndentation +
                "return holder.transform_from(GLibObject.ValueRef(raw: $1), GLibObject.ValueRef(raw: $2)) ? 1 : 0\n" + doubleIndentation +
        "}) {\n" + tripleIndentation +
            "let ptr = UnsafeRawPointer($3)\n" + tripleIndentation +
            "let holder = Unmanaged<BindingClosureHolder>.fromOpaque(ptr).takeUnretainedValue()\n" + tripleIndentation +
            "return holder.transform_to(GLibObject.ValueRef(raw: $1), GLibObject.ValueRef(raw: $2)) ? 1 : 0\n" + doubleIndentation +
        "}\n" + doubleIndentation +
        "return rv\n" + indentation +
    "}\n\n" + indentation +
    "/// Get the value of a \(classType) property\n" + indentation +
    "/// - Parameter property: the property to get the value for\n" + indentation +
    "/// - Returns: the value of the named property\n" + indentation +
    "func get(property: \(classType)PropertyName) -> GLibObject.Value {\n" + doubleIndentation +
        "let v = GLibObject.Value()\n" + doubleIndentation +
        "g_object_get_property(ptr.assumingMemoryBound(to: GObject.self), property.rawValue, v.value_ptr)\n" + doubleIndentation +
        "return v\n" + indentation +
    "}\n\n" + indentation +
    "/// Set the value of a \(classType) property.\n" + indentation +
    "/// *Note* that this will only have an effect on properties that are writable and not construct-only!\n" + indentation +
    "/// - Parameter property: the property to get the value for\n" + indentation +
    "/// - Returns: the value of the named property\n" + indentation +
    "func set(property: \(classType)PropertyName, value v: GLibObject.Value) {\n" + doubleIndentation +
        "g_object_set_property(ptr.assumingMemoryBound(to: GObject.self), property.rawValue, v.value_ptr)\n" + indentation +
    "}\n}\n\n"))
    let code = code1 + code2 + code3 + (noSignals ? "// MARK: - no signals\n" : "public enum \(classType)SignalName: String, SignalNameProtocol {\n") +
//        "public typealias Class = \(protocolName)\n") +
        signals.map(scode).joined(separator: "\n") + "\n" +
        properties.map(ncode).joined(separator: "\n") + "\n" +
    (noSignals ? "" : ("}\n\npublic extension \(protocolName) {\n" + indentation +
        "/// Connect a `\(classType)SignalName` signal to a given signal handler.\n" + indentation +
        "/// - Parameter signal: the signal to connect\n" + indentation +
        "/// - Parameter flags: signal connection flags\n" + indentation +
        "/// - Parameter handler: signal handler to use\n" + indentation +
        "/// - Returns: positive handler ID, or a value less than or equal to `0` in case of an error\n" + indentation +
        "@discardableResult func connect(signal kind: \(classType)SignalName, flags f: ConnectFlags = ConnectFlags(0), to handler: @escaping GLibObject.SignalHandler) -> CUnsignedLong {\n" + doubleIndentation +
            "func _connect(signal name: UnsafePointer<gchar>, flags: ConnectFlags, data: GLibObject.SignalHandlerClosureHolder, handler: @convention(c) @escaping (gpointer, gpointer) -> Void) -> CUnsignedLong {\n" + tripleIndentation +
                "let holder = UnsafeMutableRawPointer(Unmanaged.passRetained(data).toOpaque())\n" + tripleIndentation +
                "let callback = unsafeBitCast(handler, to: GLibObject.Callback.self)\n" + tripleIndentation +
                "let rv = GLibObject.ObjectRef(cast(\(ptr))).signalConnectData(detailedSignal: name, cHandler: callback, data: holder, destroyData: {\n" + tripleIndentation + indentation +
                    "if let swift = UnsafeRawPointer($0) {\n" + tripleIndentation + doubleIndentation +
                        "let holder = Unmanaged<GLibObject.SignalHandlerClosureHolder>.fromOpaque(swift)\n" + tripleIndentation + doubleIndentation +
                        "holder.release()\n" + tripleIndentation + indentation +
                    "}\n" + tripleIndentation + indentation +
                    "let _ = $1\n" + tripleIndentation +
                "}, connectFlags: flags)\n" + tripleIndentation +
                "return rv\n" + doubleIndentation +
            "}\n" + doubleIndentation +
            "let rv = _connect(signal: kind.name, flags: f, data: ClosureHolder(handler)) {\n" + tripleIndentation +
                "let ptr = UnsafeRawPointer($1)\n" + tripleIndentation +
                "let holder = Unmanaged<GLibObject.SignalHandlerClosureHolder>.fromOpaque(ptr).takeUnretainedValue()\n" + tripleIndentation +
                "holder.call(())\n" + doubleIndentation +
            "}\n" + doubleIndentation +
            "return rv\n" + indentation +
        "}\n" +
    "}\n\n"))
    return code
}




/// Swift code representation of a record
public func swiftCode(_ funcs: [GIR.Function]) -> (String) -> (GIR.Record) -> String {
    return { ptrName in
        { (e: GIR.Record) -> String in
            let parents = [ e.parentType?.protocolName ?? "", e.ctype == gerror ? errorProtocol : "" ].filter { !$0.isEmpty } +
                e.implements.filter { !(e.parentType?.implements.contains($0) ?? false) }.map { $0.protocolName }
            let p = recordProtocolCode(e, parent: parents.joined(separator: ", "), ptr: ptrName)
            let s = recordStructCode(e, ptr: ptrName)
            let c = recordClassCode(e, parent: "", ptr: ptrName)
            let e = recordProtocolExtensionCode(funcs, e, ptr: ptrName)
            let code = p + s + c + e
            return code
        }
    }
}


/// Swift code representation of a free standing function
public func swiftCode(_ f: GIR.Function) -> String {
    let code = functionCode(f)
    return code
}


/// Return a unions-to-swift conversion closure for the array of functions passed in
public func swiftUnionsConversion(_ funcs: [GIR.Function]) -> (GIR.Union) -> String {
    return { (u: GIR.Union) -> String in
        let ptrName = "\(u.cprefix)_ptr"
        let parents = [ u.parentType?.protocolName ?? "", u.ctype == gerror ? errorProtocol : "" ].filter { !$0.isEmpty } +
            u.implements.filter { !(u.parentType?.implements.contains($0) ?? false) }.map { $0.protocolName }
        let p = recordProtocolCode(u, parent: parents.joined(separator: ", "), ptr: ptrName)
        let s = recordStructCode(u, ptr: ptrName)
        let c = recordClassCode(u, parent: "", ptr: ptrName)
        let e = recordProtocolExtensionCode(funcs, u, ptr: ptrName)
        let code = p + s + c + e
        return code
    }
}


