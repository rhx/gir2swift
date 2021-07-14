import Foundation

/// Swift code for signal names with prefixes
struct SignalNameCode {
    let indentation: String 
    var prefixes: (String, String) = ("", "")
    var convertName: (String) -> String =  { $0.kebabSnakeCase2camelCase }

    public func signalNameCode(signal: GIR.CType) -> String {
        let name = signal.name
        let prefixedName = prefixes.0.isEmpty
            ? convertName(name)
            : prefixes.0 + convertName(name).capitalised
        let declaration = indentation + "case \(prefixedName.swift) = \"\(prefixes.1)\(name)\""
        let code = swiftCode(signal, declaration, indentation: indentation)
        return code.diagnostic()
    }
}
