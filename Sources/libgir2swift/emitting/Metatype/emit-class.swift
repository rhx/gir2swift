
/// This function builds declarations for metatypes. This feature was originaly intented to replace all of the metatype code, since dynamic features of GLib/GObject are not supported. This decision was deffered to future. Following declarations wrap only type getter for user convenience.
func buildClassTypeDeclaration(for record: GIR.Record, classInstance: GIR.Record) -> String {
    return Code.block(root: true) {
        "/// Metatype/GType declaration for \(classInstance.name.swift)"
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
    }.makeString().diagnostic()
}
