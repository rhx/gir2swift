func buildClassTypeDeclaration(for record: GIR.Record, classInstance: GIR.Record) -> String {
    return Code.block(indentation: nil) {
        "/// Metatype/GType declaration for \(classInstance.name.swift)"
        "public extension \(record.structRef.type.swiftName) {"
        Code.block {
            ""
            if let getTypeId = classInstance.typegetter {
                "/// This getter returns type identifier in the GLib type system registry"
                "public static var metatypeReference: GType { \(getTypeId)() }"
                ""
                "private static var metatypePointer: UnsafeMutablePointer<\(record.typeRef.type.ctype)>? { g_type_class_peek_static(metatypeReference)?.assumingMemoryBound(to: \(record.typeRef.type.ctype).self) }"
                ""
                "public static var metatype: \(record.typeRef.type.ctype)? { metatypePointer?.pointee } "
                ""
                "public static var wrapper: \(record.structRef.type.swiftName)? { \(record.structRef.type.swiftName)(metatypePointer) }"
                ""
            } else {
                "/// Type getter was not found in instance record associated with this class"
            }
            ""
        }
        "}"
    }
}