import Foundation

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