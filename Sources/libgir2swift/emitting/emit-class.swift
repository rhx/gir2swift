
/// This function builds declarations for metatypes.
///
/// The emitted definitions currently only wrap the type getter for user convenience.
/// A future version may replace all of the metatype code, since dynamic features of GLib/GObject are not supported,
/// but this is not currently implemented.
///
/// - Parameters:
///   - record: The Class Metatype for the given class instance.
///   - classInstance: The instantiable class instance.
/// - Returns: The static code for the reference struct to instantiate the represented type.
func buildClassTypeDeclaration(for record: GIR.Record, classInstance: GIR.Record) -> String {
    Code.block(indentation: nil) {
        "/// Metatype/GType declaration for `\(classInstance.name.swift)`"
        "public extension \(record.structRef.type.swiftName) {"
        Code.block {
            ""
            if let getTypeId = classInstance.typegetter {
                "/// Return the GLib type identifier registered for `\(classInstance.name)`"
                "@inlinable"
                "static var metatypeReference: GType { \(getTypeId)() }"
                ""
                "@usableFromInline"
                "internal static var metatypePointer: UnsafeMutablePointer<\(record.typeRef.type.ctype)>? { g_type_class_peek_static(metatypeReference)?.assumingMemoryBound(to: \(record.typeRef.type.ctype).self) }"
                ""
                "/// Return a `\(record.typeRef.type.ctype)` reference to the underlying class instance."
                "@inlinable"
                "static var metatype: \(record.typeRef.type.ctype)? { metatypePointer?.pointee } "
                ""
                "/// Return the `\(record.typeRef.type.swiftName)` wrapper referencing the metatype."
                "@inlinable"
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
                "@inlinable"
                "static func new\(classInstance.name)(properties objectType: GType, nProperties: Int, names: UnsafeMutablePointer<UnsafePointer<CChar>?>!, values: UnsafePointer<GValue>!) -> \(classInstance.name)! {"
                Code.block {
                    "let ref = GLibObject.ObjectRef(properties: objectType, nProperties: nProperties, names: names, values: values)"
                    "return \(classInstance.name)(raw: ref.ptr)"
                }
                "}"
                ""
                "/// Creates a new instance of `\(classInstance.name)` and sets its properties using"
                "/// the provided dictionary."
                "///"
                "/// Construction parameters (see `G_PARAM_CONSTRUCT`, `G_PARAM_CONSTRUCT_ONLY`)"
                "/// which are not explicitly specified are set to their default values."
                "///"
                "/// - Parameter properties: Dictionary of name/value pairs representing the properties of the type"
                "/// - Returns: A new `\(classInstance.name)` with the given properties"
                "static func newClassInstance(with properties: [String: Any] = [:]) -> \(classInstance.name)! {"
                Code.block {
                    "let type = \(getTypeId)()"
                    "var keys = properties.keys.map { $0.withCString { UnsafePointer(strdup($0)) } }"
                    "let vals = properties.values.map { GLibObject.Value($0) }"
                    "let obj = keys.withUnsafeMutableBufferPointer { keys in"
                    Code.block {
                        "withExtendedLifetime(vals) {"
                        Code.block {
                            "let gvalues = vals.map { $0.value_ptr.pointee }"
                            "return new\(classInstance.name)(properties: type, nProperties: keys.count, names: keys.baseAddress, values: gvalues)"
                        }
                        "}"
                    }
                    "}"
                    "keys.forEach { free(UnsafeMutableRawPointer(mutating: $0)) }"
                    "return obj"
                }
                "}"
            } else {
                "// A Type getter could not be found for this class"
            }
            ""
        }
        "}"
    }
}

/// Build the code for a given metatype to instantiate the underlying class.
///
/// The generated code provides a property indicating the `GType` metatype reference
/// as well as the actual metatype and a factory method to create the underlying type.
///
/// - Note: The returned code needs to go into the class definition itself (not an extension), so it can be overridden.
///
/// - Parameters:
///   - metaType: The class metatype for the given class instance.
///   - classInstance: The class instance to create the metatype properties for.
/// - Returns: The code that needs to go inside the `classInstance` class definition.
func buildCodeForClassMetaType(for metaType: GIR.Record, classInstance: GIR.Record) -> String {
    Code.block {
        if let getTypeId = classInstance.typegetter {
            "/// This getter returns the GLib type identifier registered for `\(classInstance.name)`"
            "///"
            "/// - Note: to get the type identifier through the static type, use `\(metaType.structRef.type.swiftName).metatypeReference`"
            "@inlinable"
            "public var metatypeReferenceFor\(classInstance.name): GType { \(getTypeId)() }"
            ""
            "/// Return a `\(metaType.typeRef.type.ctype)` reference to the underlying class instance."
            "@inlinable"
            "public static var metatypeFor\(classInstance.name): \(metaType.typeRef.type.ctype)? { \(metaType.structRef.type.swiftName).metatypePointer?.pointee } "
            ""
            "/// Return the `\(metaType.typeRef.type.swiftName)` wrapper referencing the metatype of the receiver."
            "@inlinable"
            "public var wrapperFor\(classInstance.name): \(metaType.structRef.type.swiftName)? { \(metaType.structRef.type.swiftName)(\(metaType.structRef.type.swiftName).metatypePointer) }"
            ""
            "/// Creates a new instance of `\(classInstance.name)` and sets its properties using"
            "/// the provided dictionary."
            "///"
            "/// Construction parameters (see `G_PARAM_CONSTRUCT`, `G_PARAM_CONSTRUCT_ONLY`)"
            "/// which are not explicitly specified are set to their default values."
            "///"
            "/// - Parameter properties: Dictionary of name/value pairs representing the properties of the type"
            "/// - Returns: A new `\(classInstance.name)` with the given properties"
            "static func new\(classInstance.name)(with properties: [String: Any] = [:]) -> \(classInstance.name)! {"
            Code.block {
                "let type = \(getTypeId)()"
                "var keys = properties.keys.map { $0.withCString { UnsafePointer(strdup($0)) } }"
                "let vals = properties.values.map { GLibObject.Value($0) }"
                "let obj = keys.withUnsafeMutableBufferPointer { keys in"
                Code.block {
                    "withExtendedLifetime(vals) {"
                    Code.block {
                        "let gvalues = vals.map { $0.value_ptr.pointee }"
                        "return \(metaType.structRef.type.swiftName).new\(classInstance.name)(properties: type, nProperties: keys.count, names: keys.baseAddress, values: gvalues)"
                    }
                    "}"
                }
                "}"
                "keys.forEach { free(UnsafeMutableRawPointer(mutating: $0)) }"
                "return obj"
            }
            "}"
        } else {
            "// A Type getter could not be found for `\(classInstance.name.swift)`"
        }
    }
}
