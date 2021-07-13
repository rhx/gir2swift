import Foundation

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

/// Swift code representation of an enum
public func swiftCode(_ bf: GIR.Bitfield) -> String {
    let indent = "    "
    let head = bitfieldTypeHead(bf, indentation: indent)
    let bitfields = bf.members
//    let names = Set(bitfields.map(\.name.camelCase.swiftQuoted))
//    let deprecated = bitfields.lazy.filter { !names.contains($0.name.swiftName) }
    let fields = bitfields.map(BitfieldValueCode(bitfield: bf, indentation: indent).bitfieldValueCode(member:)).joined(separator: "\n") // + "\n\n"
                    // + deprecated.map(bitfieldDeprecated(bf, indent)).joined(separator: "\n")
    let tail = "\n}\n\n"
    let code = head + fields + tail
    return code
}

/// Swift code representation of a bit field value
struct BitfieldValueCode {
    let bitfield: GIR.Bitfield
    let indentation: String

    public func bitfieldValueCode(member: GIR.Bitfield.Member) -> String {
        let type = bitfield.escapedName.swift
        let value = String(member.value)
        let cID: String
        if let id = member.typeRef.identifier, !id.isEmpty {
            cID = id
        } else {
            cID = value
        }
        let comment = cID == value ? "" : (" // " + cID)
        let cast = type + "(" + value + ")"
        let code = swiftCode(member, indentation + "public static let " + member.name.snakeCase2camelCase.swiftQuoted + " = " + cast + comment, indentation: indentation)
        return code
    }
}