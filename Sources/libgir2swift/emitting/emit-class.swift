
/// This function builds declarations for metatypes. This feature was originaly intented to replace all of the metatype code, since dynamic features of GLib/GObject are not supported. This decision was deffered to future. Following declarations wrap only type getter for user convenience.
func buildClassTypeDeclaration(for record: GIR.Record, classInstance: GIR.Record) -> String {
    return Code.block(indentation: nil) {
        "/// Metatype/GType declaration for `\(classInstance.name.swift)`"
        "public extension \(record.structRef.type.swiftName) {"
        Code.block {
            ""
            if let getTypeId = classInstance.typegetter {
                "/// This getter returns the GLib type identifier registered for `\(classInstance.name)`"
                "static var metatypeReference: GType { \(getTypeId)() }"
                ""
                "private static var metatypePointer: UnsafeMutablePointer<\(record.typeRef.type.ctype)>? { g_type_class_peek_static(metatypeReference)?.assumingMemoryBound(to: \(record.typeRef.type.ctype).self) }"
                ""
                "static var metatype: \(record.typeRef.type.ctype)? { metatypePointer?.pointee } "
                ""
                "static var wrapper: \(record.structRef.type.swiftName)? { \(record.structRef.type.swiftName)(metatypePointer) }"
                ""
            } else {
                "/// A Type getter could not be found for this class"
            }
            ""
        }
        "}"
        ""
        "/// static Metatype/GType methods and information"
        "public extension \(classInstance.name.swift) {"
        Code.block {
            if let getTypeId = classInstance.typegetter {
                "/// This getter returns the GLib type identifier registered for `\(classInstance.name)`"
                "static var metatypeReference: GType { \(getTypeId)() }"
                ""
                "private static var metatypePointer: UnsafeMutablePointer<\(record.typeRef.type.ctype)>? { g_type_class_peek_static(metatypeReference)?.assumingMemoryBound(to: \(record.typeRef.type.ctype).self) }"
                ""
                "static var metatype: \(record.typeRef.type.ctype)? { metatypePointer?.pointee } "
                ""
                "static var wrapper: \(record.structRef.type.swiftName)? { \(record.structRef.type.swiftName)(metatypePointer) }"
                ""
                "/// Creates a new instance of `\(classInstance.name)` and sets its properties using"
                "/// the provided dictionary."
                "///"
                "/// Construction parameters (see `G_PARAM_CONSTRUCT`, `G_PARAM_CONSTRUCT_ONLY`)"
                "/// which are not explicitly specified are set to their default values."
                "///"
                "/// - Parameter properties: Dictionary of name/value pairs representing the properties of the type"
                "/// - Returns: A new `\(classInstance.name)` with the given properties"
                "static func new(with properties: [String: Any] = [:]) -> \(classInstance.name) {"
                Code.block {
                    "let type = \(getTypeId)()"
                    "var keys = properties.keys.map { $0.withCString { UnsafePointer(strdup($0)) } }"
                    "let vals = properties.values.map { Value($0) }"
                    "let obj = keys.withUnsafeMutableBufferPointer { keys in"
                    Code.block {
                        "withExtendedLifetime(vals) {"
                        Code.block {
                            "let gvalues = vals.map { $0.value_ptr.pointee }"
                            "return \(classInstance.name)(properties: type, nProperties: keys.count, names: keys.baseAddress, values: gvalues)"
                        }
                        "}"
                    }
                    "}"
                    "keys.forEach { free(UnsafeMutableRawPointer(mutating: $0)) }"
                    "return obj"
                }
                "}"
            } else {
                "/// A Type getter could not be found for `\(classInstance.name.swift)`"
            }
        }
        "}"
    }
}
