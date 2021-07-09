import Foundation

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
