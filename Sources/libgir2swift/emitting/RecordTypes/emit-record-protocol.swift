import Foundation

/// Swift protocol representation of a record/class as a wrapper of a pointer
public func recordProtocolCode(_ e: GIR.Record, parent: String, indentation: String = "    ", ptr: String = "ptr") -> String {
    let p = (parent.isEmpty ? "" : ": \(parent)")
    let typeName = e.typeRef.type.typeName.swift
    let cOriginalType = typeName.isEmpty ? e.typeRef.type.swiftName.swift : typeName
    let ctype = cOriginalType.isEmpty ? e.name.swift : cOriginalType
    let subTypeAliases = e.records.map { subTypeAlias(e, $0, publicDesignation: "") }.joined()
    let documentation = commentCode(e)
    let code = "// MARK: - \(e.name) \(e.kind)\n\n" + documentation + "\n///\n" +
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
                                "\(ctype)! { get }\n\n") + indentation +
            "/// Required Initialiser for types conforming to `\(e.protocolName)`\n" + indentation +
            "init(raw: UnsafeMutableRawPointer)\n" +
        "}\n\n"
    return code
}

/// Default implementation for record methods as protocol extension
public func recordProtocolExtensionCode(_ globalFunctions: [GIR.Function], _ e: GIR.Record, indentation: String = "    ", ptr ptrName: String = "ptr") -> String {
    let vcode = ComputedPropertyCode(indentation: indentation, record: e, publicDesignation: "", ptrName: ptrName)
    let allFunctions = e.functions + globalFunctions
    let instanceMethods: [GIR.Method] = allFunctions.filter {
        $0.args.lazy.filter { (arg: GIR.Argument) -> Bool in
            arg.isInstanceOf(e)
        }.first != nil
    }
    let allMethods: [GIR.Method] = e.methods + instanceMethods
    let gsPairs = getterSetterPairs(for: allMethods)
    let propertyNames = Set(gsPairs.map { $0.name })
    let mcode = MethodCode(indentation: indentation, record: e, avoidingExistingNames: propertyNames, publicDesignation: "", ptrName: ptrName)
    let fcode = FieldCode(indentation: indentation, record: e, avoidExistingNames: propertyNames, publicDesignation: "", ptr: ptrName)
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
        methods.map(mcode.methodCode(method:)).joined(separator: "\n") +
        gsPairs.map(vcode.computedPropertyCode(pair:)).joined(separator: "\n") + "\n" +
        e.fields.map(fcode.fieldCode(field:)).joined(separator: "\n") + "\n" +
        subTypeProperties +
    "}\n\n"
    return code
}
