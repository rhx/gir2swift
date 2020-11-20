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
"""

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


/// a pair of getters and setters (both cannot be nil at the same time)
public struct GetterSetterPair {
    let getter: GIR.Method
    let setter: GIR.Method?
}

/// constant for "i" as a code unit
private let iU = "i".utf8.first!
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

/// GIR extension for Strings
public extension String {
    /// indicates whether the receiver is a known type
    @inlinable
    var isKnownType: Bool { return GIR.knownDataTypes[self] != nil }

    /// swift protocol name for a given string
    /// Name of the Protocol for this record
    @inlinable
    var protocolName: String { return isEmpty ? self : (self + "Protocol") }

    /// Type name without namespace prefix
    @inlinable
    var withoutDottedPrefix: String {
        guard !hasPrefix(GIR.dottedPrefix) else {
            return split(separator: ".").last ?? self
        }
        return self
    }

    /// Full type name with namespace prefix normalised
    @inlinable var withNormalisedPrefix: String {
        guard let d = firstIndex(of: ".") else { return self }
        let p = self[startIndex...d]
        guard !p.isEmpty, let prefix = GIR.namespaceReplacements[p] else { return self }
        let s = index(after: d)
        let e = endIndex
        return String(prefix + self[s..<e])
    }

    /// Dotted prefix with namespace replacements
    @inlinable var girDottedPrefix: Substring {
        let prefix = dottedPrefix
        guard let replacement = GIR.namespaceReplacements[prefix] else {
            return prefix
        }
        return replacement
    }
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

// MARK: - default Swift code for things

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

// MARK: - Swift code for Aliases

/// Swift code representation of a type alias
public func swiftCode(alias: GIR.Alias) -> String {
    let original = alias.typeRef.type.typeName.swift
    let parent = alias.typeRef.type.parent?.fullCType ?? alias.typeRef.fullCType
    let comment = original == parent ? "" : (" // " + parent)
    let code = swiftCode(alias, "public typealias " + alias.escapedName.swift + " = " + original + comment)
    return code
}

/// Swift code representation of a callback as a type alias
public func swiftCallbackAliasCode(callback: GIR.Callback) -> String {
    let original = callback.typeRef.type.typeName.swift
    let parent = callback.typeRef.type.parent?.type.typeName ?? callback.typeRef.type.ctype
    let comment = original == parent ? "" : (" // " + parent)
    let code = swiftCode(callback, "public typealias " + callback.escapedName.swift + " = " + original + comment)
    return code
}

// MARK: - Swift code for Constants

/// Swift code representation of a constant
public func swiftCode(constant: GIR.Constant) -> String {
    let original = constant.typeRef.type.typeName.swift
    let parentRef = constant.typeRef.type.parent
    let parent = parentRef?.type.typeName ?? constant.typeRef.type.ctype
    let comment = " // " + (original == parent ? "" : (parent + " value "))
    let value = "\(constant.value)"
    let name = constant.escapedName.swift
    guard !GIR.verbatimConstants.contains(name) else {
        let code = swiftCode(constant, "public let " + name +
            (parentRef == nil ? "" : (": " + parent.swift)) + " = " + value + comment + original)
        return code
    }
    let code = swiftCode(constant, "public let \(name) = \(name == original ? value : original)" + comment + (name == original ? "" : value))
    return code
}

/// Swift code type alias representation of an enum
public func typeAlias(_ e: GIR.Enumeration) -> String {
    let original = e.typeRef.type.typeName.swift
    let parent = e.typeRef.type.parent?.type.typeName ?? e.typeRef.type.ctype
    let comment = original == parent ? "" : (" // " + parent)
    let code = swiftCode(e, "public typealias " + e.escapedName.swift + " = " + original + comment)
    return code
}

// MARK: - Swift code for Enumerations

/// Swift code representation of an enum
public func swiftCode(_ e: GIR.Enumeration) -> String {
    let indentation = "    "
    let alias = typeAlias(e)
    let name = e.escapedName
//    let swift = name.swift
//    // FIXME: isErrorType never seems to be true
//    let isErrorType = name == GIR.errorT || swift == GIR.errorT
//    let ext = isErrorType ? ": \(GIR.errorProtocol.name)" : ""
//    let pub = isErrorType ? "" : "public "
    let vcf = valueCode(indentation)
//    let vdf = valueDeprecated(indentation, typeName: name)
    let values = e.members
//    let names = Set(values.map(\.name.camelCase.swiftQuoted))
//    let deprecated = values.lazy.filter { !names.contains($0.name.swiftName) }
    let head = "\n\npublic extension " + name + " {\n"
    let initialiser = """
        /// Cast constructor, converting any binary integer to a
        /// `\(name)`.
        /// - Parameter raw: The raw integer value to initialise the enum from
        @inlinable init!<I: BinaryInteger>(_ raw: I) {
            func castTo\(name)Int<I: BinaryInteger, J: BinaryInteger>(_ param: I) -> J { J(param) }
            self.init(rawValue: castTo\(name)Int(raw))
        }
    """ + "\n"
    let fields = values.map(vcf).joined(separator: "\n") // + "\n" + deprecated.map(vdf).joined(separator: "\n")
    let tail = "\n}\n\n"
    let code = alias + head + initialiser + fields + tail
    return code
}

/// Swift code representation of an enum value
public func valueCode(_ indentation: String) -> (GIR.Enumeration.Member) -> String {
    return { (m: GIR.Enumeration.Member) -> String in
        let value = String(m.value)
        let cID: String
        if let id = m.typeRef.identifier, !id.isEmpty {
            cID = id
        } else {
            cID = value
        }
        let comment = cID == value ? "" : (" // " + value)
        let code = swiftCode(m, indentation + "static let " + m.name.camelCase.swiftQuoted + " = " + cID + comment, indentation: indentation)
        return code
    }
}

///// Swift code representation of an enum value
//public func valueDeprecated(_ indentation: String, typeName: String) -> (GIR.Enumeration.Member) -> String {
//    return { (m: GIR.Enumeration.Member) -> String in
//        let value = String(m.value)
//        let cID: String
//        if let id = m.typeRef.identifier, !id.isEmpty {
//            cID = id
//        } else {
//            cID = value
//        }
//        let comment = cID == value ? "" : (" // " + value)
//        let code = swiftCode(m, indentation + "@available(*, deprecated) static let " + m.name.swiftName + " = " + typeName + "." + m.name.camelCase.swiftQuoted + comment, indentation: indentation)
//        return code
//    }
//}

// MARK: - Bitfields

/// Swift code type definition of a bitfield
public func bitfieldTypeHead(_ bf: GIR.Bitfield, enumRawType: String = "UInt32", indentation: String) -> String {
    let typeRef = bf.typeRef
    let type = typeRef.type
    let ctype = type.typeName
    let doubleIndentation = indentation + indentation
    let tripleIndentation = indentation + doubleIndentation
    return swiftCode(bf, "public struct \(bf.escapedName.swift): OptionSet {\n" + indentation +
        "/// The corresponding value of the raw type\n" + indentation +
        "public var rawValue: \(enumRawType) = 0\n" + indentation +
        "/// The equivalent raw Int value\n" + indentation +
        "@inlinable public var intValue: Int { get { Int(rawValue) } set { rawValue = \(enumRawType)(newValue) } }\n" + indentation +
        "/// The equivalent raw `gint` value\n" + indentation +
        "@inlinable public var int: gint { get { gint(rawValue) } set { rawValue = \(enumRawType)(newValue) } }\n" + indentation +
        "/// The equivalent underlying `\(ctype)` enum value\n" + indentation +
        "@inlinable public var value: \(ctype) {\n" + doubleIndentation +
          "get {\n" + tripleIndentation +
            "func castTo\(ctype)Int<I: BinaryInteger, J: BinaryInteger>(_ param: I) -> J { J(param) }\n" + tripleIndentation +
            "return " + ctype + "(rawValue: castTo\(ctype)Int(rawValue))\n" + doubleIndentation +
          "}\n" + doubleIndentation +
          "set { rawValue = \(enumRawType)(newValue.rawValue) }\n" + indentation +
        "}\n\n" + indentation +
        "/// Creates a new instance with the specified raw value\n" + indentation +
        "@inlinable public init(rawValue: \(enumRawType)) { self.rawValue = rawValue }\n" + indentation +
        "/// Creates a new instance with the specified `\(ctype)` enum value\n" + indentation +
        "@inlinable public init(_ enumValue: \(ctype)) { self.rawValue = \(enumRawType)(enumValue.rawValue) }\n" + indentation +
        "/// Creates a new instance with the specified Int value\n" + indentation +
        "@inlinable public init<I: BinaryInteger>(_ intValue: I) { self.rawValue = \(enumRawType)(intValue)  }\n\n"
    )
}

// MARK: Swift code for Bitfields

/// Swift code representation of an enum
public func swiftCode(_ bf: GIR.Bitfield) -> String {
    let indent = "    "
    let head = bitfieldTypeHead(bf, indentation: indent)
    let bitfields = bf.members
//    let names = Set(bitfields.map(\.name.camelCase.swiftQuoted))
//    let deprecated = bitfields.lazy.filter { !names.contains($0.name.swiftName) }
    let fields = bitfields.map(bitfieldValueCode(bf, indent)).joined(separator: "\n") // + "\n\n"
                    // + deprecated.map(bitfieldDeprecated(bf, indent)).joined(separator: "\n")
    let tail = "\n}\n\n"
    let code = head + fields + tail
    return code
}

/// Swift code representation of a bit field value
public func bitfieldValueCode(_ bf: GIR.Bitfield, _ indentation: String) -> (GIR.Bitfield.Member) -> String {
    let type = bf.escapedName.swift
    return { (m: GIR.Enumeration.Member) -> String in
        let value = String(m.value)
        let cID: String
        if let id = m.typeRef.identifier, !id.isEmpty {
            cID = id
        } else {
            cID = value
        }
        let comment = cID == value ? "" : (" // " + cID)
        let cast = type + "(" + value + ")"
        let code = swiftCode(m, indentation + "public static let " + m.name.camelCase.swiftQuoted + " = " + cast + comment, indentation: indentation)
        return code
    }
}


///// Deprecated Swift code representation of a bit field value
//public func bitfieldDeprecated(_ bf: GIR.Bitfield, _ indentation: String) -> (GIR.Bitfield.Member) -> String {
//    let type = bf.escapedName.swift
//    return { (m: GIR.Enumeration.Member) -> String in
//        swiftCode(m, indentation + "@available(*, deprecated) public static let \(m.name.swiftName) = \(type)(\(m.value)) /* \(m.typeRef.type.ctype) */", indentation: indentation)
//    }
//}

// MARK: - Records

/// Swift protocol representation of a record/class as a wrapper of a pointer
public func recordProtocolCode(_ e: GIR.Record, parent: String, indentation: String = "    ", ptr: String = "ptr") -> String {
    let p = (parent.isEmpty ? "" : ": \(parent)")
    let typeName = e.typeRef.type.typeName.swift
    let cOriginalType = typeName.isEmpty ? e.typeRef.type.swiftName.swift : typeName
    let ctype = cOriginalType.isEmpty ? e.name.swift : cOriginalType
    let subTypeAliases = e.records.map { subTypeAlias(e, $0, publicDesignation: "") }.joined()
    let documentation = commentCode(e)
    let code = "// MARK: - \(e.name) \(e.kind)\n\n" +
        "/// The `\(e.protocolName)` protocol exposes the methods and properties of an underlying `\(ctype)` instance.\n" +
        "/// The default implementation of these can be found in the protocol extension below.\n" +
        "/// For a concrete class that implements these methods and properties, see `\(e.className)`.\n" +
        "/// Alternatively, use `\(e.structName)` as a lighweight, `unowned` reference if you already have an instance you just want to use.\n///\n" +
            documentation + "\n" +
        "public protocol \(e.protocolName)\(p) {\n" + indentation +
            subTypeAliases + indentation +
            "/// Untyped pointer to the underlying `\(ctype)` instance.\n" + indentation +
            "var ptr: UnsafeMutableRawPointer! { get }\n\n" + indentation +
            "/// Typed pointer to the underlying `\(ctype)` instance.\n" + indentation +
            "var \(ptr): " + (e.introspectable || !e.disguised ?
                                "UnsafeMutablePointer<\(ctype)>! { get }\n\n" :
                                "\(ctype)! { get }\n\n") +
        "}\n\n"
    return code
}


/// Default implementation for record methods as protocol extension
public func recordProtocolExtensionCode(_ globalFunctions: [GIR.Function], _ e: GIR.Record, indentation: String = "    ", ptr ptrName: String = "ptr") -> String {
    let vcode = computedPropertyCode(indentation, record: e, publicDesignation: "", ptr: ptrName)
    let allFunctions = e.functions + globalFunctions
    let instanceMethods: [GIR.Method] = allFunctions.filter {
        $0.args.lazy.filter { (arg: GIR.Argument) -> Bool in
            arg.isInstanceOf(e)
        }.first != nil
    }
    let allMethods: [GIR.Method] = e.methods + instanceMethods
    let gsPairs = getterSetterPairs(for: allMethods)
    let propertyNames = Set(gsPairs.map { $0.name })
    let mcode = methodCode(indentation, record: e, avoiding: propertyNames, publicDesignation: "", ptr: ptrName)
    let fcode = fieldCode(indentation, record: e, avoiding: propertyNames, publicDesignation: "", ptr: ptrName)
    let methods = allMethods.filter { method in
        !method.name.hasPrefix("is_") || !gsPairs.contains { $0.getter === method } }
    let t = e.typeRef.type
    let typeName = t.typeName.swift
    let cOriginalType = typeName.isEmpty ? t.swiftName.swift : typeName
    let ctype = cOriginalType.isEmpty ? t.name.swift : cOriginalType
    let subTypeProperties = e.records.map { subRecordProperty(e, ptr: ptrName, $0, indentation: indentation, publicDesignation: "") }.joined()
    let code = "// MARK: \(e.name) \(e.kind): \(e.protocolName) extension (methods and fields)\n" +
        "public extension \(e.protocolName) {\n" + indentation +
        "/// Return the stored, untyped pointer as a typed pointer to the `\(ctype)` instance.\n" + indentation +
        "@inlinable var " + ptrName + ": " +
        (e.introspectable || !e.disguised ?
            "UnsafeMutablePointer<\(ctype)>! { return ptr?.assumingMemoryBound(to: \(ctype).self) }\n\n" :
            "\(ctype)! { return \(ctype)(bitPattern: UInt(bitPattern: ptr)) }\n\n") +
        methods.map(mcode).joined(separator: "\n") +
        gsPairs.map(vcode).joined(separator: "\n") + "\n" +
        e.fields.map(fcode).joined(separator: "\n") + "\n" +
        subTypeProperties +
    "}\n\n"
    return code
}


/// Type alias for sub-records
public func subTypeAlias(_ e: GIR.Record, _ r: GIR.Record, publicDesignation: String = "public ") -> String {
    let documentation = commentCode(r)
    let t = r.typeRef.type
    let typeName = t.typeName.swift
    let type = typeName.isEmpty ? t.swiftName.swift : typeName
    let classType = type.swift.capitalised
    let typeDef = publicDesignation + "typealias \(classType) = \(e.typeRef.type.ctype).__Unnamed_struct_\(t.ctype)\n"
    return documentation + typeDef
}

/// Property definition for sub-records
public func subRecordProperty(_ e: GIR.Record, ptr: String, _ r: GIR.Record, indentation: String = "    ", publicDesignation: String = "public ") -> String {
    let doubleIndentation = indentation + indentation
    let documentation = commentCode(r)
    let typeName = r.typeRef.type.typeName.swift
    let type = typeName.isEmpty ? r.typeRef.type.swiftName.swift : typeName
    let classType = type.swift.capitalised
    let name = r.name.swift
    let typeDef = indentation + publicDesignation + "@inlinable var \(name): \(classType) {\n" +
        doubleIndentation + "get { \(ptr).pointee.\(r.name) }\n" +
        doubleIndentation + "set { \(ptr).pointee.\(r.name) = newValue }\n" + indentation +
    "}\n\n"
    return documentation + typeDef
}

/// Default implementation for functions
public func functionCode(_ f: GIR.Function, indentation: String = "    ", initialIndentation i: String = "") -> String {
    let mcode = methodCode(indentation, initialIndentation: i)
    let code = mcode(f) + "\n\n"
    return code
}


/// Swift code for methods (with a given indentation)
public func methodCode(_ indentation: String, initialIndentation: String? = nil, record: GIR.Record? = nil, functionPrefix: String = "", avoiding existingNames: Set<String> = [], publicDesignation: String = "public ", convertName: @escaping (String) -> String = { $0.camelCase }, ptr ptrName: String = "ptr") -> (GIR.Method) -> String {
    let indent = initialIndentation ?? indentation
    let doubleIndent = indent + indentation
    let call = callCode(doubleIndent, record, ptr: ptrName)
    let returnDeclaration = returnDeclarationCode()
    let ret = returnCode(indentation, ptr: ptrName)
    return { (method: GIR.Method) -> String in
        let rawName = method.name.isEmpty ? method.cname : method.name
        let prefixedRawName = functionPrefix.isEmpty ? rawName : (functionPrefix + rawName.capitalised)
        let potentiallyClashingName = convertName(prefixedRawName)
        let name: String
        if existingNames.contains(potentiallyClashingName) {
            name = "get" + potentiallyClashingName.capitalised
        } else { name = potentiallyClashingName }
        guard !GIR.blacklist.contains(rawName) && !GIR.blacklist.contains(name) else {
            return "\n\(indent)// *** \(name)() causes a syntax error and is therefore not available!\n\n"
        }
        guard !method.varargs else {
            return "\n\(indent)// *** \(name)() is not available because it has a varargs (...) parameter!\n\n"
        }
        var hadInstance = false
        let arguments = method.args.filter {    // not .lazy !!!
            guard !hadInstance else {
                return true
            }
            let instance = $0.instance || $0.isInstanceOf(record)
            if instance { hadInstance = true }
            return !instance
        }
        let templateTypes = Set(arguments.compactMap(\.templateDecl)).sorted().joined(separator: ", ")
        let nonNullableTemplates = Set(arguments.compactMap(\.nonNullableTemplateDecl)).sorted().joined(separator: ", ")
        let defaultArgsCode: String
        if templateTypes.isEmpty || nonNullableTemplates == templateTypes {
            // no need to create default arguments method
            defaultArgsCode = ""
        } else {    // Create a default-nil arguments method that uses Ref instead of templates
            let templateDecl = nonNullableTemplates.isEmpty ? "" : ("<" + nonNullableTemplates + ">")
            let params = arguments.map(nullableRefParameterCode)
            let funcParam = params.joined(separator: ", ")
            let fname: String
            if let firstParamName = params.first?.split(separator: " ").first?.split(separator: ":").first?.capitalised {
                fname = name.stringByRemoving(suffix: firstParamName) ?? name
            } else {
                fname = name
            }
            let deprecated = method.deprecated != nil ? "@available(*, deprecated) " : ""
            let discardable = record?.ref?.cname == method.cname && !method.returns.isVoid ? "@discardableResult " : ""
            let inlinable = "@inlinable "
            let funcDecl = deprecated + discardable + inlinable + publicDesignation + "func " + fname.swift + templateDecl
            let paramDecl = "(" + funcParam + ")"
            let returnDecl = returnDeclaration(method)
            let callCode = call(method)
            let returnCode = ret(method)
            let bodyCode = " {\n" +
                doubleIndent + callCode +
                indent       + returnCode  + indent +
                "}\n"
            let fullFunction = indent + funcDecl + paramDecl + returnDecl + bodyCode
            defaultArgsCode = swiftCode(method, fullFunction, indentation: indent)
        }
        let templateDecl = templateTypes.isEmpty ? "" : ("<" + templateTypes + ">")
        let params = arguments.map(templatedParameterCode)
        let funcParam = params.joined(separator: ", ")
        let fname: String
        if let firstParamName = params.first?.split(separator: " ").first?.split(separator: ":").first?.capitalised {
            fname = name.stringByRemoving(suffix: firstParamName) ?? name
        } else {
            fname = name
        }
        let deprecated = method.deprecated != nil ? "@available(*, deprecated) " : ""
        let discardable = record?.ref?.cname == method.cname && !method.returns.isVoid ? "@discardableResult " : ""
        let inlinable = "@inlinable "
        let funcDecl = deprecated + discardable + inlinable + publicDesignation + "func " + fname.swift + templateDecl
        let paramDecl = "(" + funcParam + ")"
        let returnDecl = returnDeclaration(method)
        let callCode = call(method)
        let returnCode = ret(method)
        let bodyCode = " {\n" +
                doubleIndent + callCode +
                indent       + returnCode  + indent +
            "}\n"
        let fullFunction = indent + funcDecl + paramDecl + returnDecl + bodyCode
        let code = defaultArgsCode + swiftCode(method, fullFunction, indentation: indent)
        return code
    }
}


/// Swift code for computed properties
public func computedPropertyCode(_ indentation: String, record: GIR.Record, avoiding existingNames: Set<String> = [], publicDesignation: String = "public ", ptr ptrName: String = "ptr") -> (GetterSetterPair) -> String {
    let doubleIndent = indentation + indentation
    let tripleIndent = doubleIndent + indentation
    let gcall = callCode(doubleIndent, record, ptr: ptrName, doThrow: false)
    let scall = callSetter(doubleIndent, record, ptr: ptrName)
    let ret = returnCode(doubleIndent, ptr: ptrName)
    return { (pair: GetterSetterPair) -> String in
        let name: String
        if existingNames.contains(pair.name) {
            name = "_" + pair.name
        } else { name = pair.name.swiftQuoted }
        guard !GIR.blacklist.contains(name) else {
            return "\n\(indentation)// *** \(name)() causes a syntax error and is therefore not available!\n\n"
        }
        let getter = pair.getter
        let gs: GIR.Method
        let type: String
        if let rt = returnTypeCode(for: getter) {
            gs = getter
            type = rt
        } else {
            let setter = pair.setter
            guard let args = setter?.args.filter({ !$0.isInstanceOf(record) }),
                  let at = args.first, args.count == 1 else {
                return indentation + "// var \(name) is unavailable because it does not have a valid getter or setter\n"
            }
            type = at.argumentTypeName
            gs = setter!
        }
        let idiomaticType = returnTypeCode(for: gs) ?? type.idiomatic
        let property: GIR.CType
        if let prop = record.properties.filter({ $0.name.swiftQuoted == name }).first {
            property = prop
        } else {
            property = gs
        }
        let varDecl = swiftCode(property, indentation + "@inlinable \(publicDesignation)var \(name): \(idiomaticType) {\n", indentation: indentation)
        let deprecated = getter.deprecated != nil ? "@available(*, deprecated) " : ""
        let getterCode = swiftCode(getter, doubleIndent + "\(deprecated)get {\n" +
            doubleIndent + indentation + gcall(getter) +
            indentation  + ret(getter) + doubleIndent +
            "}\n", indentation: doubleIndent)
        let setterCode: String
        if let setter = pair.setter {
            let deprecated = setter.deprecated != nil ? "@available(*, deprecated) " : ""
            setterCode = swiftCode(setter, doubleIndent + "\(deprecated)nonmutating set {\n" + tripleIndent +
                (setter.throwsError ? (
                    "var error: UnsafeMutablePointer<\(GIR.gerror)>?\n" + tripleIndent
                ) : "") +
                scall(setter) +
                (setter.throwsError ? ( tripleIndent +
                    "g_log(messagePtr: error?.pointee.message, level: .error)\n"
                    ) : "") +
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
        } else { swname = potentiallyClashingName.swiftQuoted }
        guard !GIR.blacklist.contains(name) && !GIR.blacklist.contains(swname) else {
            return "\n\(indentation)// *** \(name)() causes a syntax error and is therefore not available!\n\n"
        }
        guard !field.isPrivate else { return indentation + "// var \(swname) is unavailable because \(name) is private\n" }
        let fieldType = field.containedTypes.first
        let fieldTypeRef = field.typeRef
        let containedTypeRef = fieldType?.typeRef ?? fieldTypeRef
        let pointee = ptr + ".pointee." + name
        guard field.isReadable || field.isWritable else { return indentation + "// var \(name) is unavailable because it is neigher readable nor writable\n" }
        guard !field.isVoid else { return indentation + "// var \(swname) is unavailable because \(name) is void\n" }
        let ptrLevel = fieldTypeRef.knownIndirectionLevel
        let typeName: String
        if let tupleSize = field.tupleSize, tupleSize > 0 {
            let n = field.containedTypes.count
            typeName = "(" + (0..<tupleSize).map { (i: Int) -> String in
                let type: GIR.CType = i < n ? field.containedTypes[i] : (n != 0 ? field.containedTypes[i % n] : field)
                let ref = type.typeRef
                let typeName = ref.fullTypeName
                return typeName.optionalWhenPointer
            }.joined(separator: ", ") + ")"
        } else {
            typeName = field.returnTypeName(for: record, beingIdiomatic: false, useStruct: true)
        }
        let idiomaticTypeName: String
        let varRef: TypeReference
        let fieldRef: TypeReference
        let setterExpression: String
        if ptrLevel == 0, let optionSet = field.knownBitfield {
            varRef = optionSet.underlyingCRef
            fieldRef = varRef
            idiomaticTypeName = typeName
            setterExpression = "newValue.value"
        } else if ptrLevel == 1, let knownRecord = field.knownRecord {
            varRef = knownRecord.structRef
            fieldRef = fieldTypeRef
            idiomaticTypeName = varRef.forceUnwrappedName
            setterExpression = "newValue." + knownRecord.ptrName
        } else {
            varRef = containedTypeRef
            fieldRef = varRef
            idiomaticTypeName = typeName.doForceOptional ? (typeName + "!") : typeName
            setterExpression = "newValue"
        }
        let varDecl = swiftCode(field, indentation + "@inlinable \(publicDesignation)var \(swname): \(idiomaticTypeName) {\n", indentation: indentation)
        let deprecated = field.deprecated != nil ? "@available(*, deprecated) " : ""
        let getterCode: String
        if field.isReadable {
            let cast = varRef.cast(expression: pointee, from: containedTypeRef)
            let head = doubleIndent + "\(deprecated)get {\n" + doubleIndent +
                indentation + "let rv = "
            let tail = "\n"
            getterCode = swiftCode(field, head + cast + tail +
            indentation + ret(field) + doubleIndent +
            "}\n", indentation: doubleIndent)
        } else {
            getterCode = ""
        }
        let setterCode: String
        if field.isWritable {
            let cast = fieldRef.isVoid ? setterExpression : fieldRef.cast(expression: setterExpression, from: varRef)
            let setterBody = pointee + " = " + cast
            setterCode = swiftCode(field, doubleIndent + "\(deprecated) set {\n" +
                doubleIndent + indentation + setterBody + "\n" +
                doubleIndent + "}\n", indentation: doubleIndent)
        } else {
            setterCode = ""
        }
        let varEnd = indentation + "}\n"
        return varDecl + getterCode + setterCode + varEnd
    }
}


/// Swift code for convenience constructors
public func convenienceConstructorCode(_ typeRef: TypeReference, indentation: String, convenience: String = "", override ovr: String = "", publicDesignation: String = "public ", factory: Bool = false, hasParent: Bool = false, convertName: @escaping (String) -> String = { $0.camelCase }) -> (GIR.Record) -> (GIR.Method) -> String {
    let isConv = !convenience.isEmpty
    let isExtension = publicDesignation.isEmpty
    let conv =  isConv ? "\(convenience) " : ""
    let useRef = factory && publicDesignation == "" // Only use Ref type for structs/protocols
    return { (record: GIR.Record) -> (GIR.Method) -> String in
        let doubleIndent = indentation + indentation
        let call = callCode(doubleIndent, isConstructor: !factory, useStruct: useRef)
        let returnDeclaration = returnDeclarationCode((typeRef: typeRef, record: record, isConstructor: !factory), useStruct: useRef)
        let ret = returnCode(indentation, (typeRef: typeRef, record: record, isConstructor: !factory, isConvenience: isConv), hasParent: hasParent)
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
            guard !GIR.blacklist.contains(rawName) && !GIR.blacklist.contains(name) else {
                return "\n\(indentation)// *** \(name)() causes a syntax error and is therefore not available!\n\n"
            }
            guard !method.varargs else {
                return "\n\(indentation)// *** \(name)() is not available because it has a varargs (...) parameter!\n\n"
            }
            let deprecated = method.deprecated != nil ? "@available(*, deprecated) " : ""
            let isOverride = GIR.overrides.contains(method.cname)
            let override = record.inheritedMethods.filter { $0.name == rawName }.first != nil
            let fullname = override ? convertName((method.cname.afterFirst() ?? (record.name + nameWithoutPostFix.capitalised))) : name
            let consPrefix = constructorPrefix(method)
            let fname: String
            if let prefix = consPrefix?.capitalised {
                fname = fullname.stringByRemoving(suffix: prefix) ?? fullname
            } else {
                fname = fullname
            }
            let arguments = method.args
            var vaList = false
            for argument in arguments {
                if !isExtension && argument.typeRef.type.typeName == "va_list" {
                    vaList = true
                    break
                }
            }
            guard !vaList else {
                // FIXME: as of Swift 5.3 beta, generating static class methods with va_list crashes the compiler
                return "\n\(indentation)// *** \(name)() is currently not available because \(method.cname) takes a va_list pointer!\n\n"
            }
            let templateTypes = Set(arguments.compactMap(\.templateDecl)).sorted().joined(separator: ", ")
            let templateDecl = templateTypes.isEmpty ? "" : ("<" + templateTypes + ">")
            let p: String? = consPrefix == firstArgName?.swift ? nil : consPrefix
            let fact = factory ? "static func \(fname.swift + templateDecl)(" : ("\(isOverride ? ovr : conv)init" + templateDecl + "(")
            let code = swiftCode(method, indentation + "\(deprecated)@inlinable \(publicDesignation)\(fact)" +
                constructorParam(method, prefix: p) + ")\(returnDeclaration(method)) {\n" +
                    doubleIndent + call(method) +
                    indentation  + ret(method)  + indentation +
                "}\n", indentation: indentation)
            return code
        }
    }
}


/// Return the return type of a method,
/// - Parameters:
///   - method: The method to define the return type for
///   - tr: Tuple containing information of an enclosing record
///   - beIdiomatic: Set to `true` to ensure idiomeatic Swift types are used rather than the underlying C type
///   - useRef: Set to `false` to avoid replacing the underlying typeRef with a struct reference
/// - Returns: A string containing the return type of the given method
public func returnTypeCode(for method: GIR.Method, _ tr: (typeRef: TypeReference, record: GIR.Record, isConstructor: Bool)? = nil, useIdiomaticSwift beIdiomatic: Bool = true, useStruct useRef: Bool = true) -> String? {
    let rv = method.returns
    guard !rv.isVoid, !(tr?.isConstructor ?? false) else { return nil }
    let returnTypeName = rv.returnTypeName(for: tr?.record, beingIdiomatic: beIdiomatic, useStruct: useRef)
    return returnTypeName
}



/// Return code declaration for functions/methods/convenience constructors
public func returnDeclarationCode(_ tr: (typeRef: TypeReference, record: GIR.Record, isConstructor: Bool)? = nil, useStruct useRef: Bool = true) -> (GIR.Method) -> String {
    return { method in
        let throwCode = method.throwsError ? " throws" : ""
        guard let returnType = returnTypeCode(for: method, tr, useStruct: useRef) else { return throwCode }
        return throwCode + " -> \(returnType)"
    }
}


/// Return code for functions/methods/convenience constructors
public func returnCode(_ indentation: String, _ tr: (typeRef: TypeReference, record: GIR.Record, isConstructor: Bool, isConvenience: Bool)? = nil,
                       ptr: String = "ptr", hasParent: Bool = false, useIdiomaticSwift beIdiomatic: Bool = true, noCast: Bool = false) -> (GIR.Method) -> String {
    returnCode(indentation, tr, ptr: ptr, hasParent: hasParent, useIdiomaticSwift: beIdiomatic, noCast: noCast) { $0.returns }
}

/// Return code for instances (e.g. fields)
public func instanceReturnCode(_ indentation: String, _ tr: (typeRef: TypeReference, record: GIR.Record, isConstructor: Bool, isConvenience: Bool)? = nil,
                               ptr: String = "ptr", castVar: String = "rv", hasParent: Bool = false, forceCast doForce: Bool = true, noCast: Bool = true,
                               convertToSwiftTypes doConvert: Bool = false, useIdiomaticSwift beIdiomatic: Bool = true) -> (GIR.CType) -> String {
    returnCode(indentation, tr, ptr: ptr, rv: castVar, hasParent: hasParent, forceCast: doForce, convertToSwiftTypes: doConvert, useIdiomaticSwift: beIdiomatic, noCast: noCast) { $0 }
}

/// Generic return code for methods/types
public func returnCode<T>(_ indentation: String, _ tr: (typeRef: TypeReference, record: GIR.Record, isConstructor: Bool, isConvenience: Bool)? = nil,
                          ptr: String = "ptr", rv: String = "rv", hasParent: Bool = false, forceCast doForce: Bool = false,
                          convertToSwiftTypes doConvert: Bool = true, useIdiomaticSwift beIdiomatic: Bool = true, noCast: Bool = true,
                          extract: @escaping (T) -> GIR.CType) -> (T) -> String {
    return { (param: T) -> String in
        let field = extract(param)
        guard !field.isVoid else { return "\n" }
        let isInstance = tr?.record != nil && field.isInstanceOfHierarchy((tr?.record)!)
        let fieldRef = field.typeRef
        let swiftRef = field.swiftReturnRef
        let returnRef = doConvert ? swiftRef : fieldRef
        let t = returnRef.type
        guard isInstance, let tr = tr else { return indentation + "return rv\n" }
        let typeRef = tr.typeRef
        guard !tr.isConstructor else {
            let cons = tr.isConvenience ? "self.init" : (hasParent ? "super.init(gpointer: " : "\(ptr) = UnsafeMutableRawPointer")
            let cast = "(" + rv + ")"
            let tail = tr.isConvenience || !hasParent ? "\n" : ")\n"
            let ret = indentation + cons + cast + tail
            return ret
        }
        guard !(beIdiomatic && field.idiomaticWrappedRef != swiftRef) else {
            return indentation + "return rv\n"
        }
        let cons = "return rv.map { \(t.swiftName)"
        let cast = returnRef.cast(expression: "$0", from: typeRef)
        let end = " }"
        let ret = indentation + cons + cast + end + "\n"
        return ret
    }
}


/// Swift code for calling the underlying function and assigning the raw return value
public func callCode(_ indentation: String, _ record: GIR.Record? = nil, ptr: String = "ptr", rvVar: String = "rv", doThrow: Bool = true, isConstructor: Bool = false, useStruct useRef: Bool = true) -> (GIR.Method) -> String {
    var hadInstance = false
    let toSwift: (GIR.Argument) -> String = { arg in
        let name = arg.argumentName
        guard !arg.isScalarArray else { return "&" + name }
        let instance = !hadInstance && (arg.instance || arg.isInstanceOf(record))
        if instance { hadInstance = true }
        let argPtrName: String
        if let knownRecord = arg.knownRecord {
            argPtrName = (arg.isNullable ? "?." : ".") + knownRecord.ptrName
        } else if arg.typeRef.indirectionLevel == 0 && arg.isKnownBitfield {
            argPtrName = arg.isNullable || arg.isOptional ? ".value ?? 0" : ".value"
        } else {
            argPtrName = ""
        }
        let varName = instance ? ptr : (name + argPtrName)
        let ref = arg.typeRef
        let param = ref.cast(expression: varName, from: arg.swiftParamRef)
        return param
    }
    return { method in
        hadInstance = false
        let throwsError = method.throwsError
        let args = method.args // not .lazy
        let n = args.count
        let rv = method.returns
        let isVoid = rvVar.isEmpty || rv.isVoid
        let maybeOptional = rv.maybeOptional(for: record)
        let needsNilGuard = !isVoid && maybeOptional && !isConstructor
        let errCode: String
        let throwCode: String
        let invocationTail: String
        let conditional: String
        let suffix: String
        let maybeRV: String
        if throwsError {
            maybeRV = needsNilGuard ? ("maybe" + rvVar.uppercased()) : rvVar
            conditional = ""
            suffix = ""
            errCode = "var error: UnsafeMutablePointer<\(GIR.gerror)>?\n" + indentation
            invocationTail = (n == 0 ? "" : ", ") + "&error)"
            let errorCode = "\n" + indentation + (doThrow ?
                                        "if let error = error { throw GLibError(error) }\n" :
                                        "g_log(messagePtr: error?.pointee.message, level: .error)\n")
            let nilCode = needsNilGuard ? indentation + "guard let " + rvVar + " = " + maybeRV + " else { return nil }\n" : ""
            throwCode = errorCode + nilCode
        } else {
            maybeRV = rvVar
            errCode = ""
            throwCode = "\n"
            invocationTail = ")"
            conditional = needsNilGuard ? "guard " : ""
            suffix = needsNilGuard ? " else { return nil }" : ""
        }
        let rvRef: TypeReference
        let rvSwiftRef: TypeReference
        if rv.typeRef.indirectionLevel == 0 && rv.isKnownBitfield {
            rvRef = rv.underlyingCRef
            rvSwiftRef = rv.typeRef
        } else {
            rvRef = rv.typeRef
            rvSwiftRef = !isConstructor ? (useRef ? rv.prefixedIdiomaticWrappedRef : rv.prefixedIdiomaticClassRef ) : rvRef
        }
        let invocationStart = method.cname.swift + "(\(args.map(toSwift).joined(separator: ", "))"
        let call = invocationStart + invocationTail
        let callCode = rvSwiftRef.cast(expression: call, from: rvRef)
        let rvTypeName = isConstructor || !useRef ? "" : rv.prefixedIdiomaticWrappedTypeName
        let varCode: String
        if isVoid {
            varCode = ""
        } else {
            let typeDeclaration = rvTypeName.isEmpty || callCode != call ? "" : (": " + rvTypeName)
            varCode = "let " + maybeRV + typeDeclaration + " = "
        }
        let code = errCode + conditional + varCode + callCode + suffix + throwCode
        return code
    }
}


/// Swift code for calling the underlying setter function and assigning the raw return value
public func callSetter(_ indentation: String, _ record: GIR.Record? = nil, ptr ptrName: String = "ptr") -> (GIR.Method) -> String {
    let toSwift = convertSetterArgumentToSwiftFor(record, ptr: ptrName)
    return { method in
        let args = method.args // not .lazy
        let code = ( method.returns.isVoid ? "" : "_ = " ) +
            "\(method.cname.swift)(\(args.map(toSwift).joined(separator: ", "))" +
            ( method.throwsError ? ", &error" : "" ) +
        ")\n"
        return code
    }
}

/// Swift code for the parameters of a constructor
public func constructorParam(_ method: GIR.Method, prefix: String?) -> String {
    let comma = ", "
    let args = method.args
    guard let first = args.first else { return "" }
    guard let p = prefix else { return args.map(templatedParameterCode).joined(separator: comma) }
    let firstParam = prefixedTemplatedParameterCode(for: first, prefix: p)
    let n = args.count
    guard n > 1 else { return firstParam }
    let tail = args[1..<n]
    return firstParam + comma + tail.map(templatedParameterCode).joined(separator: comma)
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

/// Swift code for a `@convention(c)` callback type declaration
/// - Parameter callback: The callback to generate type code for
/// - Returns: The Swift type for the parameter
public func callbackDecl(for callback: GIR.Callback) -> String {
    let params = callback.args.map(callbackParameterCode)
    let funcParam = params.joined(separator: ", ")
    let callbackParam: String
    if callback.throwsError {
        callbackParam = funcParam + ", UnsafeMutablePointer<UnsafeMutablePointer<" + GIR.gerror + ">?>?"
    } else {
        callbackParam = funcParam
    }
    let voidCode = "@convention(c) (" + callbackParam + ")"
    let returnTypeCodeRaw = callback.returns.returnTypeName(beingIdiomatic: false)
    let returnTypeCode: String
    if returnTypeCodeRaw.hasSuffix("!") {
        let s = returnTypeCodeRaw.startIndex
        let e = returnTypeCodeRaw.index(before: returnTypeCodeRaw.endIndex)
        returnTypeCode = returnTypeCodeRaw[s..<e] + "?"
    } else if returnTypeCodeRaw == GIR.gpointer.swiftName {
        returnTypeCode = returnTypeCodeRaw + "?"
    } else {
        returnTypeCode = returnTypeCodeRaw
    }
    let code = voidCode + " -> " + returnTypeCode
    return code
}

/// Swift code for a `@convention(c)` callback type declaration
/// - Parameter callback: The callback to generate type code for
/// - Returns: The Swift type for the parameter
public func forceUnwrappedDecl(for callback: GIR.Callback) -> String {
    let code = "(" + callbackDecl(for: callback) + ")!"
    return code
}

/// Swift code for a `@convention(c)` callback parameter
/// - Parameter argument: The argument to generate type code for
/// - Returns: The Swift type for the parameter
public func callbackParameterCode(for argument: GIR.Argument) -> String {
    let type = argument.callbackArgumentTypeName
    guard type != GIR.gpointer.swiftName else { return type + "?" }
    return type
}

/// Swift code for auto-prefixed arguments
/// This version will use template types where possible,
/// ignoring default values for those templates
/// - Parameter argument: The argument to generate type code for
/// - Returns: The Swift type for the parameter
@inlinable public func templatedParameterCode(for argument: GIR.Argument) -> String {
    let prefixedName = argument.prefixedArgumentName
    let isTemplate = argument.isKnownRecordReference
    let type = argument.templateTypeName
    let escaping = type.maybeCallback ? "@escaping " : ""
    let defaultValue = !isTemplate && argument.isNullable && argument.allowNone ? " = nil" : ""
    let code = prefixedName + ": " + escaping + type + defaultValue
    return code
}

/// Swift code for method parameters
@inlinable public func prefixedTemplatedParameterCode(for argument: GIR.Argument, prefix: String) -> String {
    let name = argument.argumentName
    let prefixedName = prefix + " " + name
    let isTemplate = argument.isKnownRecordReference
    let type = argument.templateTypeName
    let escaping = type.maybeCallback ? "@escaping " : ""
    let defaultValue = !isTemplate && argument.isNullable && argument.allowNone ? " = nil" : ""
    let code = prefixedName + ": " + escaping + type + defaultValue
    return code
}

/// Swift code for auto-prefixed arguments.
/// This version will use `Ref` (struct) types instead of templats
/// for nullable reference arguments with a default value of `nil`
/// - Parameter argument: The argument to generate type code for
/// - Returns: The Swift type for the parameter
@inlinable public func nullableRefParameterCode(for argument: GIR.Argument) -> String {
    let prefixedName = argument.prefixedArgumentName
    let type = argument.defaultRefTemplateTypeName
    let escaping = type.maybeCallback ? "@escaping " : ""
    let defaultValue = argument.isNullable && argument.allowNone ? " = nil" : ""
    let code = prefixedName + ": " + escaping + type + defaultValue
    return code
}

/// Swift code for method parameters
@inlinable public func prefixedNullableRefParameterCode(for argument: GIR.Argument, prefix: String) -> String {
    let name = argument.argumentName
    let prefixedName = prefix + " " + name
    let type = argument.defaultRefTemplateTypeName
    let escaping = type.maybeCallback ? "@escaping " : ""
    let defaultValue = argument.isNullable && argument.allowNone ? " = nil" : ""
    let code = prefixedName + ": " + escaping + type + defaultValue
    return code
}

/// Swift code for auto-prefixed return values
public func returnCode(for argument: GIR.Argument) -> String {
    let prefixedname = argument.prefixedArgumentName
    let type = argument.argumentTypeName
    let code = "\(prefixedname): \(type)"
    return code
}


/// Swift code for method return values
public func returnCode(for argument: GIR.Argument, prefix: String) -> String {
    let name = argument.argumentName
    let type = argument.returnTypeName
    let code = "\(prefix) \(name): \(type)"
    return code
}


/// Swift code for passing an argument to a free standing function
public func toSwift(_ arg: GIR.Argument, ptr: String = "ptr") -> String {
    let t = arg.typeRef.type
    let varName = arg.instance ? ptr : (arg.nonClashingName + (arg.isKnownRecord ? ".ptr" : ""))
    let param = t.cast(expression: varName)
    return param
}


/// Swift code for passing a setter to a method of a record / class
public func convertSetterArgumentToSwiftFor(_ record: GIR.Record?, ptr: String = "ptr") -> (GIR.Argument) -> String {
    return { arg in
        let name = arg.nonClashingName
        guard !arg.isScalarArray else { return "&" + name }
        let ref = arg.typeRef
        let paramRef = arg.swiftParamRef
        let sourceRef: TypeReference
        let exp: String
        if !arg.instance && !arg.isInstanceOf(record) && paramRef.knownIndirectionLevel == 1, let knownRecord = GIR.knownRecords[paramRef.type.name] {
            exp = "newValue?." + knownRecord.ptrName
            sourceRef = knownRecord.structRef
        } else if arg.instance || arg.isInstanceOf(record) {
            exp = ptr
            sourceRef = paramRef
        } else if paramRef.indirectionLevel == 0 && arg.isKnownBitfield {
            exp = arg.isNullable || arg.isOptional ? "newValue?.value ?? 0" : "newValue.value"
            sourceRef = paramRef
        } else {
            exp = "newValue"
            sourceRef = paramRef
        }
        let param = ref.cast(expression: exp, from: sourceRef)
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
    let doubleIndentation = indentation + indentation
    let typeRef = e.typeRef
    let t = typeRef.type
    let structRef = e.structRef
    let structType = structRef.type
    let structName = structType.swiftName
    let protocolRef = e.protocolRef
    let protocolType = protocolRef.type
    let protocolName = protocolType.swiftName
    let cOriginalType = t.ctype.isEmpty ? t.typeName.swift : t.ctype.swift
    let ctype = cOriginalType.isEmpty ? t.name.swift : cOriginalType
    let ccode = convenienceConstructorCode(structRef, indentation: indentation, publicDesignation: "")(e)
    let fcode = convenienceConstructorCode(structRef, indentation: indentation, publicDesignation: "", factory: true)(e)
    let constructors = e.constructors.filter { $0.isConstructorOf(e) && !$0.isBareFactory }
    let allFunctions: [GIR.Method] = e.methods + e.functions
    let factories: [GIR.Method] = (e.constructors + allFunctions).filter { $0.isFactoryOf(e) }
    let subTypeAliases = e.records.map { subTypeAlias(e, $0, publicDesignation: "") }.joined()
    let documentation = commentCode(e)
    let code = "/// The `\(structName)` type acts as a lightweight Swift reference to an underlying `\(ctype)` instance.\n" +
    "/// It exposes methods that can operate on this data type through `\(protocolName)` conformance.\n" +
    "/// Use `\(structName)` only as an `unowned` reference to an existing `\(ctype)` instance.\n///\n" +
        documentation + "\n" +
    "public struct \(structName): \(protocolName) {\n" + indentation +
        subTypeAliases + indentation +
        "/// Untyped pointer to the underlying `\(ctype)` instance.\n" + indentation +
        "/// For type-safe access, use the generated, typed pointer `\(ptr)` property instead.\n" + indentation +
        "public let ptr: UnsafeMutableRawPointer!\n" +
    "}\n\n" +
    "public extension \(structName) {\n" + indentation +
        "/// Designated initialiser from the underlying `C` data type\n" + indentation +
        "@inlinable init(_ p: UnsafeMutablePointer<\(ctype)>) {\n" + doubleIndentation +
            "ptr = UnsafeMutableRawPointer(p)\n" + indentation +
        "}\n\n" + indentation +
        "/// Designated initialiser from a constant pointer to the underlying `C` data type\n" + indentation +
        "@inlinable init(_ p: UnsafePointer<\(ctype)>) {\n" + doubleIndentation +
            "ptr = UnsafeMutableRawPointer(UnsafeMutablePointer(mutating: p))\n" + indentation +
        "}\n\n" + indentation +
        "/// Conditional initialiser from an optional pointer to the underlying `C` data type\n" + indentation +
        "@inlinable init!(_ maybePointer: UnsafeMutablePointer<\(ctype)>?) {\n" + doubleIndentation +
        "guard let p = maybePointer else { return nil }\n" + doubleIndentation +
        "ptr = UnsafeMutableRawPointer(p)\n" + indentation +
        "}\n\n" + indentation +
        "/// Conditional initialiser from an optional, non-mutable pointer to the underlying `C` data type\n" + indentation +
        "@inlinable init!(_ maybePointer: UnsafePointer<\(ctype)>?) {\n" + doubleIndentation +
        "guard let p = UnsafeMutablePointer(mutating: maybePointer) else { return nil }\n" + doubleIndentation +
        "ptr = UnsafeMutableRawPointer(p)\n" + indentation +
        "}\n\n" + indentation +
        "/// Conditional initialiser from an optional `gpointer`\n" + indentation +
        "@inlinable init!(" + GIR.gpointer + " g: " + GIR.gpointer + "?) {\n" + doubleIndentation +
        "guard let p = g else { return nil }\n" + doubleIndentation +
        "ptr = UnsafeMutableRawPointer(p)\n" + indentation +
        "}\n\n" + indentation +
        "/// Conditional initialiser from an optional, non-mutable `gconstpointer`\n" + indentation +
        "@inlinable init!(" + GIR.gconstpointer + " g: " + GIR.gconstpointer + "?) {\n" + doubleIndentation +
        "guard let p = UnsafeMutableRawPointer(mutating: g) else { return nil }\n" + doubleIndentation +
        "ptr = p\n" + indentation +
        "}\n\n" + indentation +
        "/// Reference intialiser for a related type that implements `\(protocolName)`\n" + indentation +
        "@inlinable init<T: \(protocolName)>(_ other: T) {\n" + doubleIndentation +
            "ptr = other.ptr\n" + indentation +
        "}\n\n" + indentation +
        "/// Unsafe typed initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "@inlinable init<T>(cPointer: UnsafeMutablePointer<T>) {\n" + doubleIndentation +
            "ptr = UnsafeMutableRawPointer(cPointer)\n" + indentation +
        "}\n\n" + indentation +
        "/// Unsafe typed initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "@inlinable init<T>(constPointer: UnsafePointer<T>) {\n" + doubleIndentation +
            "ptr = UnsafeMutableRawPointer(mutating: UnsafeRawPointer(constPointer))\n" + indentation +
        "}\n\n" + indentation +
        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "@inlinable init(mutating raw: UnsafeRawPointer) {\n" + doubleIndentation +
            "ptr = UnsafeMutableRawPointer(mutating: raw)\n" + indentation +
        "}\n\n" + indentation +
        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "@inlinable init(raw: UnsafeMutableRawPointer) {\n" + doubleIndentation +
            "ptr = raw\n" + indentation +
        "}\n\n" + indentation +
        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "@inlinable init(opaquePointer: OpaquePointer) {\n" + doubleIndentation +
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
    let className = e.name.swift
    let instance = className.deCapitalised
    let typeRef = e.typeRef
    let t = typeRef.type
    let protocolRef = e.protocolRef
    let protocolType = protocolRef.type
    let protocolName = protocolType.swiftName
    let cOriginalType = t.ctype.isEmpty ? t.typeName.swift : t.ctype.swift
    let ctype = cOriginalType.isEmpty ? t.name.swift : cOriginalType
    let cGIRType = GIRType(name: ctype, ctype: ctype)
//    let ctypeRef = TypeReference.pointer(to: cGIRType)
    let parentType = e.parentType
    let hasParent = parentType != nil || !parent.isEmpty
    let scode = signalNameCode(indentation: indentation)
    let ccode = convenienceConstructorCode(typeRef, indentation: indentation, override: "override ", hasParent: hasParent)(e)
    let fcode = convenienceConstructorCode(typeRef, indentation: indentation, factory: true)(e)
    let constructors = e.constructors.filter { $0.isConstructorOf(e) && !$0.isBareFactory }
    let allmethods = e.allMethods
    let factories = allmethods.filter { $0.isFactoryOf(e) }
    let properties = e.allProperties
    let noProperties = properties.isEmpty
    let retain: String
    let retainPtr: String
    if let ref = e.ref, ref.args.count == 1 {
        retain = ref.cname
        retainPtr = RawPointerConversion(source: cGIRType, target: GIR.rawPointerType).castFromTarget(expression: "ptr")
    } else {
        retain = "// no reference counting for \(ctype.swift), cannot ref"
        retainPtr = ptr
    }
    let release: String
    let releasePtr: String
    if let unref = e.unref, unref.args.count == 1 {
        release = unref.cname
        releasePtr = RawPointerConversion(source: cGIRType, target: GIR.rawPointerType).castFromTarget(expression: "ptr")
    } else {
        release = "// no reference counting for \(ctype.swift), cannot unref"
        releasePtr = ptr
    }
    let parentName = parent.isEmpty ? parentType?.name.withNormalisedPrefix.swift ?? "" : parent
    let p = parentName.isEmpty ? "" : (parentName + ", ")
    let documentation = commentCode(e)
    let subTypeAliases = e.records.map { subTypeAlias(e, $0) }.joined()
    let code1 = "/// The `\(className)` type acts as a\(e.ref == nil ? "n" : " reference-counted") owner of an underlying `\(ctype)` instance.\n" +
    "/// It provides the methods that can operate on this data type through `\(protocolName)` conformance.\n" +
    "/// Use `\(className)` as a strong reference or owner of a `\(ctype)` instance.\n///\n" +
        documentation + "\n" +
    "open class \(className): \(p)\(protocolName) {\n" + indentation +
       subTypeAliases + indentation +
        (hasParent ? "" : (
            "/// Untyped pointer to the underlying `\(ctype)` instance.\n" + indentation +
            "/// For type-safe access, use the generated, typed pointer `\(ptr)` property instead.\n" + indentation +
            "public let ptr: UnsafeMutableRawPointer!\n\n" + indentation)
        ) +
        "/// Designated initialiser from the underlying `C` data type.\n" + indentation +
        "/// This creates an instance without performing an unbalanced retain\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n" + indentation +
        "@inlinable public init(_ op: UnsafeMutablePointer<\(ctype)>) {\n" + doubleIndentation +
            (hasParent ? "super.init(cPointer: op)\n" : "ptr = UnsafeMutableRawPointer(op)\n") + indentation +
        "}\n\n" + (indentation +
        "/// Designated initialiser from a constant pointer to the underlying `C` data type.\n" + indentation +
        "/// This creates an instance without performing an unbalanced retain\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n" + indentation +
        "@inlinable public init(_ op: UnsafePointer<\(ctype)>) {\n" + doubleIndentation +
            (hasParent ? "super.init(raw: UnsafeMutableRawPointer(UnsafeMutablePointer(mutating: op)))\n" : "ptr = UnsafeMutableRawPointer(UnsafeMutablePointer(mutating: op))\n") + indentation +
        "}\n\n") + (indentation +
        "/// Optional initialiser from a non-mutating `" + GIR.gpointer + "` to\n" + indentation +
        "/// the underlying `C` data type.\n" + indentation +
        "/// This creates an instance without performing an unbalanced retain\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: gpointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init!(" + GIR.gpointer + " op: " + GIR.gpointer + "?) {\n" + doubleIndentation +
            "guard let p = UnsafeMutableRawPointer(op) else { return nil }\n" + doubleIndentation +
            (hasParent ? "super.init(raw: p)\n" : "ptr = p\n") + indentation +
        "}\n\n") + (indentation +
        "/// Optional initialiser from a non-mutating `" + GIR.gconstpointer + "` to\n" + indentation +
        "/// the underlying `C` data type.\n" + indentation +
        "/// This creates an instance without performing an unbalanced retain\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init!(" + GIR.gconstpointer + " op: " + GIR.gconstpointer + "?) {\n" + doubleIndentation +
            "guard let p = op else { return nil }\n" + doubleIndentation +
            (hasParent ? "super.init(raw: p)\n" : "ptr = UnsafeMutableRawPointer(mutating: p)\n") + indentation +
        "}\n\n") + (indentation +

        "/// Optional initialiser from a constant pointer to the underlying `C` data type.\n" + indentation +
        "/// This creates an instance without performing an unbalanced retain\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n" + indentation +
        "@inlinable public init!(_ op: UnsafePointer<\(ctype)>?) {\n" + doubleIndentation +
            "guard let p = UnsafeMutablePointer(mutating: op) else { return nil }\n" + doubleIndentation +
            (hasParent ? "super.init(cPointer: p)\n" : "ptr = UnsafeMutableRawPointer(p)\n") + indentation +
        "}\n\n") + (indentation +
        "/// Optional initialiser from the underlying `C` data type.\n" + indentation +
        "/// This creates an instance without performing an unbalanced retain\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n" + indentation +
        "@inlinable public init!(_ op: UnsafeMutablePointer<\(ctype)>?) {\n" + doubleIndentation +
            "guard let p = op else { return nil }\n" + doubleIndentation +
            (hasParent ? "super.init(cPointer: p)\n" : "ptr = UnsafeMutableRawPointer(p)\n") + indentation +
        "}\n\n") + (indentation +

        "/// Designated initialiser from the underlying `C` data type.\n" + indentation +
        "/// \(e.ref == nil ? "`\(ctype.swift)` does not allow reference counting, so despite the name no actual retaining will occur." : "Will retain `\(ctype.swift)`.")\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n") + (indentation +
        "@inlinable public init(retaining op: UnsafeMutablePointer<\(ctype)>) {\n" + doubleIndentation +
            (hasParent ?
                "super.init(retainingCPointer: op)\n" :
                "ptr = UnsafeMutableRawPointer(op)\n" + doubleIndentation +
                "\(retain)(\(retainPtr))\n") + indentation +
        "}\n\n") + (indentation +

        "/// Reference intialiser for a related type that implements `\(protocolName)`\n" + indentation +
        "/// \(e.ref == nil ? "`\(ctype.swift)` does not allow reference counting." : "Will retain `\(ctype.swift)`.")\n" + indentation +
        "/// - Parameter other: an instance of a related type that implements `\(protocolName)`\n" + indentation +
        "@inlinable public init<T: \(protocolName)>(\(hasParent ? instance : "_") other: T) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingRaw: other.ptr)\n" :
            "ptr = other.ptr\n" + doubleIndentation +
            "\(retain)(\(retainPtr))\n") + indentation +
        "}\n\n") + (hasParent ? "" : (indentation +

        "/// \(e.unref == nil ? "Do-nothing destructor for `\(ctype.swift)`." : "Releases the underlying `\(ctype.swift)` instance using `\(e.unref?.cname ?? "unref")`.")\n" + indentation +
        "deinit {\n" + indentation + indentation +
            "\(release)(\(releasePtr))\n" + indentation +
        "}\n\n")) + ((indentation +

        "/// Unsafe typed initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter cPointer: pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init<T>(cPointer p: UnsafeMutablePointer<T>) {\n" + doubleIndentation +
            (hasParent ? "super.init(cPointer: p)\n" : "ptr = UnsafeMutableRawPointer(p)\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe typed, retaining initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter cPointer: pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init<T>(retainingCPointer cPointer: UnsafeMutablePointer<T>) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingCPointer: cPointer)\n" :
            "ptr = UnsafeMutableRawPointer(cPointer)\n" + doubleIndentation +
            "\(retain)(\(retainPtr))\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter p: raw pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init(raw p: UnsafeRawPointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(raw: p)\n" : "ptr = UnsafeMutableRawPointer(mutating: p)\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped, retaining initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init(retainingRaw raw: UnsafeRawPointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingRaw: raw)\n" :
            "ptr = UnsafeMutableRawPointer(mutating: raw)\n" + doubleIndentation +
            "\(retain)(\(retainPtr))\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter p: mutable raw pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init(raw p: UnsafeMutableRawPointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(raw: p)\n" : "ptr = p\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped, retaining initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter raw: mutable raw pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init(retainingRaw raw: UnsafeMutableRawPointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingRaw: raw)\n" :
            "ptr = raw\n" + doubleIndentation +
            "\(retain)(\(retainPtr))\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter p: opaque pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init(opaquePointer p: OpaquePointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(opaquePointer: p)\n" : "ptr = UnsafeMutableRawPointer(p)\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped, retaining initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter p: opaque pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init(retainingOpaquePointer p: OpaquePointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingOpaquePointer: p)\n" :
            "ptr = UnsafeMutableRawPointer(p)\n" + doubleIndentation +
            "\(retain)(\(retainPtr))\n") + indentation +
        "}\n\n"))
    let code2 = constructors.map(ccode).joined(separator: "\n") + "\n" +
        factories.map(fcode).joined(separator: "\n") + "\n" +
    "}\n\n"
    let code3 = String(noProperties ? "// MARK: no \(className) properties\n" : "public enum \(className)PropertyName: String, PropertyNameProtocol {\n") +
//        "public typealias Class = \(protocolName)\n") +
        properties.map(scode).joined(separator: "\n") + "\n" +
    (noProperties ? "" : ("}\n\npublic extension \(protocolName) {\n" + indentation +
        "/// Bind a `\(className)PropertyName` source property to a given target object.\n" + indentation +
        "/// - Parameter source_property: the source property to bind\n" + indentation +
        "/// - Parameter target: the target object to bind to\n" + indentation +
        "/// - Parameter target_property: the target property to bind to\n" + indentation +
        "/// - Parameter flags: the flags to pass to the `Binding`\n" + indentation +
        "/// - Parameter transform_from: `ValueTransformer` to use for forward transformation\n" + indentation +
        "/// - Parameter transform_to: `ValueTransformer` to use for backwards transformation\n" + indentation +
        "/// - Returns: binding reference or `nil` in case of an error\n" + indentation +
        "@discardableResult @inlinable func bind<Q: PropertyNameProtocol, T: GLibObject.ObjectProtocol>(property source_property: \(className)PropertyName, to target: T, _ target_property: Q, flags f: BindingFlags = .default, transformFrom transform_from: @escaping GLibObject.ValueTransformer = { $0.transform(destValue: $1) }, transformTo transform_to: @escaping GLibObject.ValueTransformer = { $0.transform(destValue: $1) }) -> BindingRef! {\n" + doubleIndentation +
            "func _bind(_ source: UnsafePointer<gchar>, to t: T, _ target_property: UnsafePointer<gchar>, flags f: BindingFlags = .default, holder: BindingClosureHolder, transformFrom transform_from: @convention(c) @escaping (gpointer, gpointer, gpointer, gpointer) -> gboolean, transformTo transform_to: @convention(c) @escaping (gpointer, gpointer, gpointer, gpointer) -> gboolean) -> BindingRef! {\n" + tripleIndentation +
                "let holder = UnsafeMutableRawPointer(Unmanaged.passRetained(holder).toOpaque())\n" + tripleIndentation +
                "let from = unsafeBitCast(transform_from, to: BindingTransformFunc.self)\n" + tripleIndentation +
                "let to   = unsafeBitCast(transform_to,   to: BindingTransformFunc.self)\n" + tripleIndentation +
                "let rv = GLibObject.ObjectRef(raw: ptr).bindPropertyFull(sourceProperty: source, target: t, targetProperty: target_property, flags: f, transformTo: to, transformFrom: from, userData: holder) {\n" + tripleIndentation + indentation +
                    "if let swift = UnsafeRawPointer($0) {\n" + tripleIndentation + doubleIndentation +
                        "let holder = Unmanaged<GLibObject.SignalHandlerClosureHolder>.fromOpaque(swift)\n" + tripleIndentation + doubleIndentation +
                        "holder.release()\n" + tripleIndentation + indentation +
                    "}\n" + tripleIndentation +
                "}\n" + tripleIndentation +
                "return rv.map { BindingRef($0) }\n" + doubleIndentation +
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
    "/// Get the value of a \(className) property\n" + indentation +
    "/// - Parameter property: the property to get the value for\n" + indentation +
    "/// - Returns: the value of the named property\n" + indentation +
    "@inlinable func get(property: \(className)PropertyName) -> GLibObject.Value {\n" + doubleIndentation +
        "let v = GLibObject.Value()\n" + doubleIndentation +
        "g_object_get_property(ptr.assumingMemoryBound(to: GObject.self), property.rawValue, v.value_ptr)\n" + doubleIndentation +
        "return v\n" + indentation +
    "}\n\n" + indentation +
    "/// Set the value of a \(className) property.\n" + indentation +
    "/// *Note* that this will only have an effect on properties that are writable and not construct-only!\n" + indentation +
    "/// - Parameter property: the property to get the value for\n" + indentation +
    "/// - Returns: the value of the named property\n" + indentation +
    "@inlinable func set(property: \(className)PropertyName, value v: GLibObject.Value) {\n" + doubleIndentation +
        "g_object_set_property(ptr.assumingMemoryBound(to: GObject.self), property.rawValue, v.value_ptr)\n" + indentation +
    "}\n}\n\n"))
    return code1 + code2 + code3 + buildSignalExtension(for: e)
}

// MARK: - Swift code for Record/Class methods

/// Swift code representation of a record
public func swiftCode(_ funcs: [GIR.Function]) -> (String) -> (GIR.Record) -> String {
    return { ptrName in
        { (r: GIR.Record) -> String in
            let cl = r as? GIR.Class
            let ctype = r.typeRef.type.ctype
            let parents = [
                cl?.parent.protocolName.withNormalisedPrefix ?? r.parentType?.protocolName.withNormalisedPrefix ?? "",
                ctype == GIR.gerror ? GIR.errorProtocol.name : ""
            ].filter { !$0.isEmpty } + r.implements.filter {
                !(r.parentType?.implements.contains($0) ?? false)
            }.map { $0.protocolName.withNormalisedPrefix }
            let p = recordProtocolCode(r, parent: parents.joined(separator: ", "), ptr: ptrName)
            let s = recordStructCode(r, ptr: ptrName)
            let c = recordClassCode(r, parent: cl?.parent.withNormalisedPrefix ?? "", ptr: ptrName)
            let e = recordProtocolExtensionCode(funcs, r, ptr: ptrName)
            let code = p + s + c + e
            return code
        }
    }
}


// MARK: Swift code for free functions

/// Swift code representation of a free standing function
public func swiftCode(_ f: GIR.Function) -> String {
    let code = functionCode(f)
    return code
}

// MARK: - Union conversions

/// Return a unions-to-swift conversion closure for the array of functions passed in
public func swiftUnionsConversion(_ funcs: [GIR.Function]) -> (GIR.Union) -> String {
    return { (u: GIR.Union) -> String in
        let ptrName = u.ptrName
        let ctype = u.typeRef.type.ctype
        let parents = [ u.parentType?.protocolName ?? "", ctype == GIR.gerror ? GIR.errorProtocol.name : "" ].filter { !$0.isEmpty } +
            u.implements.filter { !(u.parentType?.implements.contains($0) ?? false) }.map { $0.protocolName }
        let p = recordProtocolCode(u, parent: parents.joined(separator: ", "), ptr: ptrName)
        let s = recordStructCode(u, ptr: ptrName)
        let c = recordClassCode(u, parent: "", ptr: ptrName)
        let e = recordProtocolExtensionCode(funcs, u, ptr: ptrName)
        let code = p + s + c + e
        return code
    }
}


