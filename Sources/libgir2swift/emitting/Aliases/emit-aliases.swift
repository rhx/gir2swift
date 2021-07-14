import Foundation

/// Swift code representation of a type alias
public func swiftCode(alias: GIR.Alias) -> String {
    let original = alias.typeRef.type.typeName.swift
    let parent = alias.typeRef.type.parent?.fullCType ?? alias.typeRef.fullCType
    let comment = original == parent ? "" : (" // " + parent)
    let code = swiftCode(alias, "public typealias " + alias.escapedName.swift + " = " + original + comment)
    return code.diagnostic()
}

/// Swift code representation of a callback as a type alias
public func swiftCallbackAliasCode(callback: GIR.Callback) -> String {
    let original = callback.typeRef.type.typeName.swift
    let parent = callback.typeRef.type.parent?.type.typeName ?? callback.typeRef.type.ctype
    let comment = original == parent ? "" : (" // " + parent)
    let code = swiftCode(callback, "public typealias " + callback.escapedName.swift + " = " + original + comment)
    return code.diagnostic()
}

/// Type alias for sub-records
public func subTypeAlias(_ e: GIR.Record, _ r: GIR.Record, publicDesignation: String = "public ") -> String {
    let documentation = commentCode(r)
    let t = r.typeRef.type
    let typeName = t.typeName.swift
    let type = typeName.isEmpty ? t.swiftName.swift : typeName
    let classType = type.swift.capitalised
    let typeDef = publicDesignation + "typealias \(classType) = \(e.typeRef.type.ctype).__Unnamed_struct_\(t.ctype)\n"
    return (documentation + typeDef).diagnostic()
}