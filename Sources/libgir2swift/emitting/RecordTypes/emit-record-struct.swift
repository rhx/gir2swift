import Foundation

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
    let ccode = ConvenienceConstructorCode(typeRef: structRef, indentation: indentation, publicDesignation: "")
    let fcode = ConvenienceConstructorCode(typeRef: structRef, indentation: indentation, publicDesignation: "", factory: true)
    let constructors = e.constructors.filter { $0.isConstructorOf(e) && !$0.isBareFactory }
    let allFunctions: [GIR.Method] = e.methods + e.functions
    let factories: [GIR.Method] = (e.constructors + allFunctions).filter { $0.isFactoryOf(e) }
    let subTypeAliases = e.records.map { subTypeAlias(e, $0, publicDesignation: "") }.joined()
    let documentation = commentCode(e)
    
    // In case wrapped value supports GObject reference countin, add GWeakCapturing protocol conformance to support GWeak<T> requirements.
    let weakReferencable = e.rootType.name == "Object" && e.ref != nil
    let weakReferencingProtocol = weakReferencable ? ", GWeakCapturing" : ""
    
    let code = "/// The `\(structName)` type acts as a lightweight Swift reference to an underlying `\(ctype)` instance.\n" +
    "/// It exposes methods that can operate on this data type through `\(protocolName)` conformance.\n" +
    "/// Use `\(structName)` only as an `unowned` reference to an existing `\(ctype)` instance.\n///\n" +
        documentation + "\n" +
    "public struct \(structName): \(protocolName)\(weakReferencingProtocol) {\n" + indentation +
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
        // This factory is syntactic sugar for conversion owning class wrapers to unowning structs. This feature was added to introduce better syntax for working with GWeak<T> class.
        (weakReferencable 
            ? 
            (
                "/// This factory is syntactic sugar for setting weak pointers wrapped in `GWeak<T>`\n" + indentation +
                "@inlinable static func unowned<T: \(protocolName)>(_ other: T) -> \(structName) { \(structName)(other) }\n\n" + indentation
            )
            : ""
        ) +
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
        constructors.map { ccode.convenienceConstructorCode(record: e, method: $0) }.joined(separator: "\n") +
        factories.map { fcode.convenienceConstructorCode(record: e, method: $0) }.joined(separator: "\n") +
    "}\n\n"
    return code
}