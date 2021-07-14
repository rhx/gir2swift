import Foundation

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
    let vcf = ValueCode(indentation: indentation)
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
    let fields = values.map(vcf.valueCode(member:)).joined(separator: "\n") // + "\n" + deprecated.map(vdf).joined(separator: "\n")
    let tail = "\n}\n\n"
    let code = alias + head + initialiser + fields + tail
    return code.diagnostic()
}

/// Swift code representation of an enum value
struct ValueCode {
    let indentation: String

    func valueCode(member: GIR.Enumeration.Member) -> String {
        let value = String(member.value)
        let cID: String
        if let id = member.typeRef.identifier, !id.isEmpty {
            cID = id
        } else {
            cID = value
        }
        let comment = cID == value ? "" : (" // " + value)
        let code = swiftCode(member, indentation + "static let " + member.name.snakeCase2camelCase.swiftQuoted + " = " + cID + comment, indentation: indentation)
        return code.diagnostic()
    }    
}
