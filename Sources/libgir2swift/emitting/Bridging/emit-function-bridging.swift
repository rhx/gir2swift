import Foundation


/// Default implementation for functions
public func functionCode(_ f: GIR.Function, indentation: String = "    ", initialIndentation i: String = "") -> String {
    let mcode = MethodCode(indentation: indentation, initialIndentation: i)
    let code = mcode.methodCode(method: f) + "\n\n"
    return code.diagnostic()
}


/// Swift code for methods (with a given indentation)
struct MethodCode {
    let indentation: String
    var initialIndentation: String? = nil
    var record: GIR.Record? = nil
    var functionPrefix: String = ""
    var avoidingExistingNames: Set<String> = []
    var publicDesignation: String = "public "
    var convertName: (String) -> String = \.snakeCase2camelCase
    var ptrName: String = "ptr"

    public func methodCode(method: GIR.Method) -> String {
        let indent = initialIndentation ?? indentation
        let doubleIndent = indent + indentation
        var call = CallCode(indentation: doubleIndent, record: record, ptr: ptrName)
        let returnDeclaration = ReturnDeclarationCode()
        let ret = ReturnCode(indentation: indentation, ptr: ptrName)
        let rawName = method.name.isEmpty ? method.cname : method.name
        let prefixedRawName = functionPrefix.isEmpty ? rawName : (functionPrefix + rawName.capitalised)
        let potentiallyClashingName = convertName(prefixedRawName)
        let name: String
        if avoidingExistingNames.contains(potentiallyClashingName) {
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
            if let firstParamName = params.first?.components(separatedBy: " ").first?.components(separatedBy: ":").first?.capitalised {
                fname = name.stringByRemoving(suffix: firstParamName) ?? name
            } else {
                fname = name
            }
            let deprecated = method.deprecated != nil ? "@available(*, deprecated) " : ""
            let discardable = record?.ref?.cname == method.cname && !method.returns.isVoid ? "@discardableResult " : ""
            let inlinable = "@inlinable "
            let funcDecl = deprecated + discardable + inlinable + publicDesignation + "func " + fname.swift + templateDecl
            let paramDecl = "(" + funcParam + ")"
            let returnDecl = returnDeclaration.returnDeclarationCode(method: method)
            let callCode = call.callCode(method: method)
            let returnCode = ret.returnCode(method: method)
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
        if let firstParamName = params.first?.components(separatedBy: " ").first?.components(separatedBy: ":").first?.capitalised {
            fname = name.stringByRemoving(suffix: firstParamName) ?? name
        } else {
            fname = name
        }
        let deprecated = method.deprecated != nil ? "@available(*, deprecated) " : ""
        let discardable = record?.ref?.cname == method.cname && !method.returns.isVoid ? "@discardableResult " : ""
        let inlinable = "@inlinable "
        let funcDecl = deprecated + discardable + inlinable + publicDesignation + "func " + fname.swift + templateDecl
        let paramDecl = "(" + funcParam + ")"
        let returnDecl = returnDeclaration.returnDeclarationCode(method: method)
        let callCode = call.callCode(method: method)
        let returnCode = ret.returnCode(method: method)
        let bodyCode = " {\n" +
                doubleIndent + callCode +
                indent       + returnCode  + indent +
            "}\n"
        let fullFunction = indent + funcDecl + paramDecl + returnDecl + bodyCode
        let code = defaultArgsCode + swiftCode(method, fullFunction, indentation: indent)
        return code.diagnostic()
    }
}

struct ComputedPropertyCode {
    let indentation: String 
    let record: GIR.Record
    var avoidExistingNames: Set<String> = []
    var publicDesignation: String = "public "
    var ptrName: String = "ptr"

        /// Swift code for computed properties
    public func computedPropertyCode(pair: GetterSetterPair) -> String {
        let doubleIndent = indentation + indentation
        let tripleIndent = doubleIndent + indentation
        var gcall = CallCode(indentation: doubleIndent, record: record, ptr: ptrName, doThrow: false)
        let scall = CallSetter(indentation: doubleIndent, record: record, ptrName: ptrName)
        let ret = ReturnCode(indentation: doubleIndent, ptr: ptrName)
        let name: String
        if avoidExistingNames.contains(pair.name) {
            name = "_" + pair.name
        } else { name = pair.name.swiftQuoted }
        guard !GIR.blacklist.contains(name) else {
            return "\n\(indentation)// *** \(name)() causes a syntax error and is therefore not available!\n\n".diagnostic()
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
                return (indentation + "// var \(name) is unavailable because it does not have a valid getter or setter\n").diagnostic()
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
            doubleIndent + indentation + gcall.callCode(method: getter) +
            indentation  + ret.returnCode(method: getter) + doubleIndent +
            "}\n", indentation: doubleIndent)
        let setterCode: String
        if let setter = pair.setter {
            let deprecated = setter.deprecated != nil ? "@available(*, deprecated) " : ""
            setterCode = swiftCode(setter, doubleIndent + "\(deprecated)nonmutating set {\n" + tripleIndent +
                (setter.throwsError ? (
                    "var error: UnsafeMutablePointer<\(GIR.gerror)>?\n" + tripleIndent
                ) : "") +
                scall.callSetter(method: setter) +
                (setter.throwsError ? ( tripleIndent +
                    "g_log(messagePtr: error?.pointee.message, level: .error)\n"
                    ) : "") +
                doubleIndent + "}\n", indentation: doubleIndent)
        } else {
            setterCode = ""
        }
        let varEnd = indentation + "}\n"
        return (varDecl + getterCode + setterCode + varEnd).diagnostic()
    }
}

struct FieldCode {
    let indentation: String
    let record: GIR.Record
    var avoidExistingNames: Set<String> = []
    var publicDesignation: String = "public "
    var ptr: String = "_ptr"
    /// Swift code for field properties
    public func fieldCode(field: GIR.Field) -> String {
        let doubleIndent = indentation + indentation
        let name = field.name
        let potentiallyClashingName = name.snakeCase2camelCase
        let swname: String
        if avoidExistingNames.contains(potentiallyClashingName) {
            let underscored = "_" + potentiallyClashingName
            if avoidExistingNames.contains(underscored) {
                swname = underscored + "_"
            } else {
                swname = underscored
            }
        } else { swname = potentiallyClashingName.swiftQuoted }
        guard !GIR.blacklist.contains(name) && !GIR.blacklist.contains(swname) else {
            return "\n\(indentation)// *** \(name)() causes a syntax error and is therefore not available!\n\n".diagnostic()
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
            indentation + instanceReturnCode(doubleIndent, ptr: "rv", castVar: "rv", cType: field) + doubleIndent +
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
        return (varDecl + getterCode + setterCode + varEnd).diagnostic()
    }
}


/// Swift code for convenience constructors
struct ConvenienceConstructorCode {
    let typeRef: TypeReference
    let indentation: String
    var convenience: String = ""
    var overrideStr: String = "" 
    var publicDesignation: String = "public "
    var factory: Bool = false
    var hasParent: Bool = false
    var shouldSink: Bool = false
    var convertName: (String) -> String = \.snakeCase2camelCase

    public func convenienceConstructorCode(record: GIR.Record, method: GIR.Method) -> String {
        let isConv = !convenience.isEmpty
        let isExtension = publicDesignation.isEmpty
        let conv =  isConv ? "\(convenience) " : ""
        let useRef = factory && publicDesignation == "" // Only use Ref type for structs/protocols
        let doubleIndent = indentation + indentation    
        var call = CallCode(indentation: doubleIndent, isConstructor: !factory, useStruct: useRef)
        let returnDeclaration = ReturnDeclarationCode(tr: (typeRef: typeRef, record: record, isConstructor: !factory), useStructRef: useRef)
        let ret = ReturnCode(indentation: indentation, tr: (typeRef: typeRef, record: record, isConstructor: !factory, isConvenience: isConv), hasParent: hasParent)
        let isGObject = record.rootType.name == "Object" && record.ref != nil && shouldSink
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
            return "\n\(indentation)// *** \(name)() causes a syntax error and is therefore not available!\n\n".diagnostic()
        }
        guard !method.varargs else {
            return "\n\(indentation)// *** \(name)() is not available because it has a varargs (...) parameter!\n\n".diagnostic()
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
            return "\n\(indentation)// *** \(name)() is currently not available because \(method.cname) takes a va_list pointer!\n\n".diagnostic()
        }
        let templateTypes = Set(arguments.compactMap(\.templateDecl)).sorted().joined(separator: ", ")
        let templateDecl = templateTypes.isEmpty ? "" : ("<" + templateTypes + ">")
        let p: String? = consPrefix == firstArgName?.swift ? nil : consPrefix
        let fact = factory ? "static func \(fname.swift + templateDecl)(" : ("\(isOverride ? overrideStr : conv)init" + templateDecl + "(")

        // This code will consume floating references upon instantiation. This is suggested by the GObject documentation since Floating references are C-specific syntactic sugar.
        // https://developer.gnome.org/gobject/stable/gobject-The-Base-Object-Type.html
        let retainBlock = isGObject ?
            doubleIndent + "if typeIsA(type: \(factory ? "rv" : "self").type, isAType: InitiallyUnownedClassRef.metatypeReference) { _ = \(factory ? "rv" : "self").refSink() } \n"
            : "" 

        let code = swiftCode(method, indentation + "\(deprecated)@inlinable \(publicDesignation)\(fact)" +
            constructorParam(method, prefix: p) + ")\(returnDeclaration.returnDeclarationCode(method: method)) {\n" +
                doubleIndent + call.callCode(method: method) +
                (factory ? retainBlock : "") +
                indentation  + ret.returnCode(method: method) +
                (!factory ? retainBlock : "") +
            indentation + "}\n", indentation: indentation)
        return code.diagnostic()
    
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
    return returnTypeName.diagnostic()
}

/// Return code declaration for functions/methods/convenience constructors
struct ReturnDeclarationCode {
    var tr: (typeRef: TypeReference, record: GIR.Record, isConstructor: Bool)? = nil
    var useStructRef: Bool = true

    public func returnDeclarationCode(method: GIR.Method) -> String {
        let throwCode = method.throwsError ? " throws" : ""
        guard let returnType = returnTypeCode(for: method, tr, useStruct: useStructRef) else { return throwCode.diagnostic() }
        return (throwCode + " -> \(returnType)").diagnostic()
    }
}

/// Return code for functions/methods/convenience constructors
struct ReturnCode {
    let indentation: String
    var tr: (typeRef: TypeReference, record: GIR.Record, isConstructor: Bool, isConvenience: Bool)? = nil
    var ptr: String = "ptr"
    var hasParent: Bool = false
    var useIdiomaticSwift: Bool = true
    var noCast: Bool = false

    public func returnCode(method: GIR.Method) -> String {
        GenericReturnCode<GIR.Method>(indentation: indentation, tr: tr, ptr: ptr, hasParent: hasParent, useIdiomaticSwift: useIdiomaticSwift, noCast: noCast, extract: { $0.returns } ).returnCode(param: method).diagnostic()
    }
}

/// Return code for instances (e.g. fields)
public func instanceReturnCode(
    _ indentation: String, 
    _ tr: (typeRef: TypeReference, record: GIR.Record, isConstructor: Bool, isConvenience: Bool)? = nil,
    ptr: String = "ptr", 
    castVar: String = "rv", 
    hasParent: Bool = false, 
    forceCast doForce: Bool = true, 
    noCast: Bool = true,
    convertToSwiftTypes doConvert: Bool = false, 
    useIdiomaticSwift beIdiomatic: Bool = true,
    cType: GIR.CType
) -> String {
    GenericReturnCode(indentation: indentation, tr: tr, ptr: ptr, rv: castVar, hasParent: hasParent, forceCast: doForce, convertToSwiftTypes: doConvert, useIdiomaticSwift: beIdiomatic, noCast: noCast, extract: {$0} ).returnCode(param: cType).diagnostic()
}

/// Generic return code for methods/types
struct GenericReturnCode<T> {
    let indentation: String
    var tr: (typeRef: TypeReference, record: GIR.Record, isConstructor: Bool, isConvenience: Bool)? = nil
    var ptr: String = "ptr"
    var rv: String = "rv"
    var hasParent: Bool = false
    var forceCast : Bool = false
    var convertToSwiftTypes: Bool = true
    var useIdiomaticSwift: Bool = true
    var noCast: Bool = true
    let extract: (T) -> GIR.CType

    public func returnCode(param: T) -> String {
        let field = extract(param)
        guard !field.isVoid else { return "\n" }
        let isInstance = tr?.record != nil && field.isInstanceOfHierarchy((tr?.record)!)
        let fieldRef = field.typeRef
        let swiftRef = field.swiftReturnRef
        let returnRef = convertToSwiftTypes ? swiftRef : fieldRef
        let t = returnRef.type
        guard isInstance, let tr = tr else { return (indentation + "return rv\n").diagnostic() }
        let typeRef = tr.typeRef
        guard !tr.isConstructor else {
            let cons = tr.isConvenience ? "self.init" : (hasParent ? "super.init(gpointer: " : "\(ptr) = UnsafeMutableRawPointer")
            let cast = "(" + rv + ")"
            let tail = tr.isConvenience || !hasParent ? "\n" : ")\n"
            let ret = indentation + cons + cast + tail
            return ret.diagnostic()
        }
        guard !(useIdiomaticSwift && field.idiomaticWrappedRef != swiftRef) else {
            return (indentation + "return rv\n").diagnostic()
        }
        let cons = "return rv.map { \(t.swiftName)"
        let cast = returnRef.cast(expression: "$0", from: typeRef)
        let end = " }"
        let ret = indentation + cons + cast + end + "\n"
        return ret.diagnostic()
    }
}


/// Swift code for calling the underlying function and assigning the raw return value
struct CallCode {
    let indentation: String
    var record: GIR.Record? = nil
    var ptr: String = "ptr"
    var rvVar: String = "rv"
    var doThrow: Bool = true
    var isConstructor: Bool = false
    var useStruct: Bool = true

    /* private */
    var hadInstance = false

    private mutating func toSwift(_ arg: GIR.Argument) -> String {
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
        return param.diagnostic()
    }

    public mutating func callCode(method: GIR.Method) -> String {
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
            rvSwiftRef = !isConstructor ? (useStruct ? rv.prefixedIdiomaticWrappedRef : rv.prefixedIdiomaticClassRef ) : rvRef
        }
        let invocationStart = method.cname.swift + "(\(args.map { self.toSwift($0) }.joined(separator: ", "))"
        let call = invocationStart + invocationTail
        let callCode = rvSwiftRef.cast(expression: call, from: rvRef)
        let rvTypeName = isConstructor || !useStruct ? "" : rv.prefixedIdiomaticWrappedTypeName
        let varCode: String
        if isVoid {
            varCode = ""
        } else {
            let typeDeclaration = rvTypeName.isEmpty || callCode != call ? "" : (": " + rvTypeName)
            varCode = "let " + maybeRV + typeDeclaration + " = "
        }
        let code = errCode + conditional + varCode + callCode + suffix + throwCode
        return code.diagnostic()
    }
}

/// Swift code for calling the underlying setter function and assigning the raw return value
struct CallSetter {
    let indentation: String
    var record: GIR.Record? = nil
    var ptrName: String = "ptr"

    public func callSetter(method: GIR.Method) -> String {
        let toSwift = ConvertSetterArgumentToSwiftFor(record: record, ptr: ptrName)
        let args = method.args // not .lazy
        let code = ( method.returns.isVoid ? "" : "_ = " ) +
            "\(method.cname.swift)(\(args.map(toSwift.convertSetterArgumentToSwiftFor(arg:)).joined(separator: ", "))" +
            ( method.throwsError ? ", &error" : "" ) +
        ")\n"
        return code.diagnostic()
    }
}

/// Swift code for the parameters of a constructor
public func constructorParam(_ method: GIR.Method, prefix: String?) -> String {
    let comma = ", "
    let args = method.args
    guard let first = args.first else { return "".diagnostic() }
    guard let p = prefix else { return args.map(templatedParameterCode).joined(separator: comma).diagnostic() }
    let firstParam = prefixedTemplatedParameterCode(for: first, prefix: p)
    let n = args.count
    guard n > 1 else { return firstParam.diagnostic() }
    let tail = args[1..<n]
    return (firstParam + comma + tail.map(templatedParameterCode).joined(separator: comma)).diagnostic()
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
            return String(name[s..<e]).swift.diagnostic()
        }
        if let suffix = (["_newv", "_new"].lazy.filter { name.hasSuffix($0) }.first) {
            let s = name.startIndex
            let e = name.index(name.endIndex, offsetBy: -suffix.count)
            return String(name[s..<e]).swift.diagnostic()
        }
        return nil
    }
    let f = components.startIndex + from.offset + 1
    let e = components.endIndex
    let s = f < e ? f : f - 1
    let name = components[s..<e].joined(separator: "_")
    return name.snakeCase2camelCase.swift.diagnostic()
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
    return code.diagnostic()
}

/// Swift code for a `@convention(c)` callback type declaration
/// - Parameter callback: The callback to generate type code for
/// - Returns: The Swift type for the parameter
public func forceUnwrappedDecl(for callback: GIR.Callback) -> String {
    let code = "(" + callbackDecl(for: callback) + ")!"
    return code.diagnostic()
}

/// Swift code for a `@convention(c)` callback parameter
/// - Parameter argument: The argument to generate type code for
/// - Returns: The Swift type for the parameter
public func callbackParameterCode(for argument: GIR.Argument) -> String {
    let type = argument.callbackArgumentTypeName
    guard type != GIR.gpointer.swiftName else { return type + "?" }
    return type.diagnostic()
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
    return code.diagnostic()
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
    return code.diagnostic()
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
    return code.diagnostic()
}

/// Swift code for method parameters
@inlinable public func prefixedNullableRefParameterCode(for argument: GIR.Argument, prefix: String) -> String {
    let name = argument.argumentName
    let prefixedName = prefix + " " + name
    let type = argument.defaultRefTemplateTypeName
    let escaping = type.maybeCallback ? "@escaping " : ""
    let defaultValue = argument.isNullable && argument.allowNone ? " = nil" : ""
    let code = prefixedName + ": " + escaping + type + defaultValue
    return code.diagnostic()
}

/// Swift code for auto-prefixed return values
public func returnCode(for argument: GIR.Argument) -> String {
    let prefixedname = argument.prefixedArgumentName
    let type = argument.argumentTypeName
    let code = "\(prefixedname): \(type)"
    return code.diagnostic()
}


/// Swift code for method return values
public func returnCode(for argument: GIR.Argument, prefix: String) -> String {
    let name = argument.argumentName
    let type = argument.returnTypeName
    let code = "\(prefix) \(name): \(type)"
    return code.diagnostic()
}


/// Swift code for passing an argument to a free standing function
public func toSwift(_ arg: GIR.Argument, ptr: String = "ptr") -> String {
    let t = arg.typeRef.type
    let varName = arg.instance ? ptr : (arg.nonClashingName + (arg.isKnownRecord ? ".ptr" : ""))
    let param = t.cast(expression: varName)
    return param.diagnostic()
}


/// Swift code for passing a setter to a method of a record / class
struct ConvertSetterArgumentToSwiftFor {
    let record: GIR.Record?
    var ptr: String = "ptr"

    public func convertSetterArgumentToSwiftFor(arg: GIR.Argument) -> String {
        let name = arg.nonClashingName
        guard !arg.isScalarArray else { return ("&" + name).diagnostic() }
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
        return param.diagnostic()
    }
}
