import Foundation

extension String {
    @usableFromInline func diagnostic(function name: String = #function) -> String {
        if Gir2Swift.diagnostic {
            return "\n/*\(name) <*/" + self + "/*> \(name)*/\n"
        } else {
            return self
        }
    }
}