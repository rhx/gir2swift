import Foundation

/// Swift struct representation of a record/class as a wrapper of a pointer
public func recordClassCode(_ e: GIR.Record, parent: String, indentation: String = "    ", ptr: String = "ptr") -> String {
    let doubleIndentation = indentation + indentation
    let tripleIndentation = indentation + doubleIndentation
    let className = e.name.swift
    let instance = className.deCapitalised
    let typeRef = e.typeRef
    let t = typeRef.type
    let protocolRef = e.protocolRef
    let protocolType = protocolRef.type
    let protocolName = protocolType.swiftName
    let cOriginalType = t.ctype.isEmpty ? t.typeName.swift : t.ctype.swift
    let ctype = cOriginalType.isEmpty ? t.name.swift : cOriginalType
    let cGIRType = GIRType(name: ctype, ctype: ctype)
//    let ctypeRef = TypeReference.pointer(to: cGIRType)
    let parentType = e.parentType
    let hasParent = parentType != nil || !parent.isEmpty
    let scode = SignalNameCode(indentation: indentation)
    let ncode = SignalNameCode(indentation: indentation, prefixes: ("notify", "notify::"))
    let ccode = ConvenienceConstructorCode(typeRef: typeRef, indentation: indentation, overrideStr: "override ", hasParent: hasParent, shouldSink: true)
    let fcode = ConvenienceConstructorCode(typeRef: typeRef, indentation: indentation, factory: true, shouldSink: true)
    let constructors = e.constructors.filter { $0.isConstructorOf(e) && !$0.isBareFactory }
    let allmethods = e.allMethods
    let factories = allmethods.filter { $0.isFactoryOf(e) }
    let properties = e.allProperties
    let signals = e.allSignals
    let noProperties = properties.isEmpty
    let noSignals = noProperties && signals.isEmpty
    let retain: String
    let retainPtr: String
    // Disable required initalisers for Value wrappers. AppLaunchContext is hardcoded because of a bug that causes it to report a wrong base when generating gdk wrappers.
    let isObject = e.rootType.name == "Object" || e.rootType.name == "AppLaunchContext";
    if let ref = e.ref, ref.args.count == 1 {
        retain = ref.cname
        retainPtr = RawPointerConversion(source: cGIRType, target: GIR.rawPointerType).castFromTarget(expression: "ptr")
    } else {
        retain = "// no reference counting for \(ctype.swift), cannot ref"
        retainPtr = ptr
    }
    let release: String
    let releasePtr: String
    if let unref = e.unref, unref.args.count == 1 {
        release = unref.cname
        releasePtr = RawPointerConversion(source: cGIRType, target: GIR.rawPointerType).castFromTarget(expression: "ptr")
    } else {
        release = "// no reference counting for \(ctype.swift), cannot unref"
        releasePtr = ptr
    }
    let parentName = parent.isEmpty ? parentType?.name.withNormalisedPrefix.swift ?? "" : parent
    let p = parentName.isEmpty ? "" : (parentName + ", ")
    let documentation = commentCode(e)
    let subTypeAliases = e.records.map { subTypeAlias(e, $0) }.joined()
    let code1 = "/// The `\(className)` type acts as a\(e.ref == nil ? "n" : " reference-counted") owner of an underlying `\(ctype)` instance.\n" +
    "/// It provides the methods that can operate on this data type through `\(protocolName)` conformance.\n" +
    "/// Use `\(className)` as a strong reference or owner of a `\(ctype)` instance.\n///\n" +
        documentation + "\n" +
    "open class \(className): \(p)\(protocolName) {\n" + indentation +
       subTypeAliases + indentation +
        (hasParent ? "" : (
            "/// Untyped pointer to the underlying `\(ctype)` instance.\n" + indentation +
            "/// For type-safe access, use the generated, typed pointer `\(ptr)` property instead.\n" + indentation +
            "public let ptr: UnsafeMutableRawPointer!\n\n" + indentation)
        ) +
        "/// Designated initialiser from the underlying `C` data type.\n" + indentation +
        "/// This creates an instance without performing an unbalanced retain\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n" + indentation +
        "@inlinable public init(_ op: UnsafeMutablePointer<\(ctype)>) {\n" + doubleIndentation +
            (hasParent ? "super.init(cPointer: op)\n" : "ptr = UnsafeMutableRawPointer(op)\n") + indentation +
        "}\n\n" + (indentation +
        "/// Designated initialiser from a constant pointer to the underlying `C` data type.\n" + indentation +
        "/// This creates an instance without performing an unbalanced retain\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n" + indentation +
        "@inlinable public init(_ op: UnsafePointer<\(ctype)>) {\n" + doubleIndentation +
            (hasParent ? "super.init(raw: UnsafeMutableRawPointer(UnsafeMutablePointer(mutating: op)))\n" : "ptr = UnsafeMutableRawPointer(UnsafeMutablePointer(mutating: op))\n") + indentation +
        "}\n\n") + (indentation +
        "/// Optional initialiser from a non-mutating `" + GIR.gpointer + "` to\n" + indentation +
        "/// the underlying `C` data type.\n" + indentation +
        "/// This creates an instance without performing an unbalanced retain\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: gpointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init!(" + GIR.gpointer + " op: " + GIR.gpointer + "?) {\n" + doubleIndentation +
            "guard let p = UnsafeMutableRawPointer(op) else { return nil }\n" + doubleIndentation +
            (hasParent ? "super.init(raw: p)\n" : "ptr = p\n") + indentation +
        "}\n\n") + (indentation +
        "/// Optional initialiser from a non-mutating `" + GIR.gconstpointer + "` to\n" + indentation +
        "/// the underlying `C` data type.\n" + indentation +
        "/// This creates an instance without performing an unbalanced retain\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init!(" + GIR.gconstpointer + " op: " + GIR.gconstpointer + "?) {\n" + doubleIndentation +
            "guard let p = op else { return nil }\n" + doubleIndentation +
            (hasParent ? "super.init(raw: p)\n" : "ptr = UnsafeMutableRawPointer(mutating: p)\n") + indentation +
        "}\n\n") + (indentation +

        "/// Optional initialiser from a constant pointer to the underlying `C` data type.\n" + indentation +
        "/// This creates an instance without performing an unbalanced retain\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n" + indentation +
        "@inlinable public init!(_ op: UnsafePointer<\(ctype)>?) {\n" + doubleIndentation +
            "guard let p = UnsafeMutablePointer(mutating: op) else { return nil }\n" + doubleIndentation +
            (hasParent ? "super.init(cPointer: p)\n" : "ptr = UnsafeMutableRawPointer(p)\n") + indentation +
        "}\n\n") + (indentation +
        "/// Optional initialiser from the underlying `C` data type.\n" + indentation +
        "/// This creates an instance without performing an unbalanced retain\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n" + indentation +
        "@inlinable public init!(_ op: UnsafeMutablePointer<\(ctype)>?) {\n" + doubleIndentation +
            "guard let p = op else { return nil }\n" + doubleIndentation +
            (hasParent ? "super.init(cPointer: p)\n" : "ptr = UnsafeMutableRawPointer(p)\n") + indentation +
        "}\n\n") + (indentation +

        "/// Designated initialiser from the underlying `C` data type.\n" + indentation +
        "/// \(e.ref == nil ? "`\(ctype.swift)` does not allow reference counting, so despite the name no actual retaining will occur." : "Will retain `\(ctype.swift)`.")\n" + indentation +
        "/// i.e., ownership is transferred to the `\(className)` instance.\n" + indentation +
        "/// - Parameter op: pointer to the underlying object\n") + (indentation +
        "@inlinable public init(retaining op: UnsafeMutablePointer<\(ctype)>) {\n" + doubleIndentation +
            (hasParent ?
                "super.init(retainingCPointer: op)\n" :
                "ptr = UnsafeMutableRawPointer(op)\n" + doubleIndentation +
                "\(retain)(\(retainPtr))\n") + indentation +
        "}\n\n") + (indentation +

        "/// Reference intialiser for a related type that implements `\(protocolName)`\n" + indentation +
        "/// \(e.ref == nil ? "`\(ctype.swift)` does not allow reference counting." : "Will retain `\(ctype.swift)`.")\n" + indentation +
        "/// - Parameter other: an instance of a related type that implements `\(protocolName)`\n" + indentation +
        "@inlinable public init<T: \(protocolName)>(\(hasParent ? instance : "_") other: T) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingRaw: other.ptr)\n" :
            "ptr = other.ptr\n" + doubleIndentation +
            "\(retain)(\(retainPtr))\n") + indentation +
        "}\n\n") + (hasParent ? "" : (indentation +

        "/// \(e.unref == nil ? "Do-nothing destructor for `\(ctype.swift)`." : "Releases the underlying `\(ctype.swift)` instance using `\(e.unref?.cname ?? "unref")`.")\n" + indentation +
        "deinit {\n" + indentation + indentation +
            "\(release)(\(releasePtr))\n" + indentation +
        "}\n\n")) + ((indentation +

        "/// Unsafe typed initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter cPointer: pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init<T>(cPointer p: UnsafeMutablePointer<T>) {\n" + doubleIndentation +
            (hasParent ? "super.init(cPointer: p)\n" : "ptr = UnsafeMutableRawPointer(p)\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe typed, retaining initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter cPointer: pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init<T>(retainingCPointer cPointer: UnsafeMutablePointer<T>) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingCPointer: cPointer)\n" :
            "ptr = UnsafeMutableRawPointer(cPointer)\n" + doubleIndentation +
            "\(retain)(\(retainPtr))\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter p: raw pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init(raw p: UnsafeRawPointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(raw: p)\n" : "ptr = UnsafeMutableRawPointer(mutating: p)\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped, retaining initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init(retainingRaw raw: UnsafeRawPointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingRaw: raw)\n" :
            "ptr = UnsafeMutableRawPointer(mutating: raw)\n" + doubleIndentation +
            "\(retain)(\(retainPtr))\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter p: mutable raw pointer to the underlying object\n" + indentation + "@inlinable " +
        "public required init(raw p: UnsafeMutableRawPointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(raw: p)\n" : "ptr = p\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped, retaining initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter raw: mutable raw pointer to the underlying object\n" + indentation + "@inlinable " +
        // We add required to this initialiser on objects so that it can be used to instantiate generic types constrained to a subclass of object.
        (isObject ? "required ": hasParent ? "override ": "") +
        "public init(retainingRaw raw: UnsafeMutableRawPointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingRaw: raw)\n" :
            "ptr = raw\n" + doubleIndentation +
            "\(retain)(\(retainPtr))\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter p: opaque pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init(opaquePointer p: OpaquePointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(opaquePointer: p)\n" : "ptr = UnsafeMutableRawPointer(p)\n") + indentation +
        "}\n\n") + (indentation +

        "/// Unsafe untyped, retaining initialiser.\n" + indentation +
        "/// **Do not use unless you know the underlying data type the pointer points to conforms to `\(protocolName)`.**\n" + indentation +
        "/// - Parameter p: opaque pointer to the underlying object\n" + indentation + "@inlinable " +
        (hasParent ? "override " : "") +
        "public init(retainingOpaquePointer p: OpaquePointer) {\n" + doubleIndentation +
            (hasParent ? "super.init(retainingOpaquePointer: p)\n" :
            "ptr = UnsafeMutableRawPointer(p)\n" + doubleIndentation +
            "\(retain)(\(retainPtr))\n") + indentation +
        "}\n\n"))
    let code2 = constructors.map { ccode.convenienceConstructorCode(record: e, method: $0) }.joined(separator: "\n") + "\n" +
        factories.map { fcode.convenienceConstructorCode(record: e, method: $0) }.joined(separator: "\n") + "\n" +
    "}\n\n"
    let code3 = String(noProperties ? "// MARK: no \(className) properties\n" : "public enum \(className)PropertyName: String, PropertyNameProtocol {\n") +
//        "public typealias Class = \(protocolName)\n") +
        properties.map(scode.signalNameCode(signal:)).joined(separator: "\n") + "\n" +
    (noProperties ? "" : ("}\n\npublic extension \(protocolName) {\n" + indentation +
        "/// Bind a `\(className)PropertyName` source property to a given target object.\n" + indentation +
        "/// - Parameter source_property: the source property to bind\n" + indentation +
        "/// - Parameter target: the target object to bind to\n" + indentation +
        "/// - Parameter target_property: the target property to bind to\n" + indentation +
        "/// - Parameter flags: the flags to pass to the `Binding`\n" + indentation +
        "/// - Parameter transform_from: `ValueTransformer` to use for forward transformation\n" + indentation +
        "/// - Parameter transform_to: `ValueTransformer` to use for backwards transformation\n" + indentation +
        "/// - Returns: binding reference or `nil` in case of an error\n" + indentation +
        "@discardableResult @inlinable func bind<Q: PropertyNameProtocol, T: GLibObject.ObjectProtocol>(property source_property: \(className)PropertyName, to target: T, _ target_property: Q, flags f: BindingFlags = .default, transformFrom transform_from: @escaping GLibObject.ValueTransformer = { $0.transform(destValue: $1) }, transformTo transform_to: @escaping GLibObject.ValueTransformer = { $0.transform(destValue: $1) }) -> BindingRef! {\n" + doubleIndentation +
            "func _bind(_ source: UnsafePointer<gchar>, to t: T, _ target_property: UnsafePointer<gchar>, flags f: BindingFlags = .default, holder: BindingClosureHolder, transformFrom transform_from: @convention(c) @escaping (gpointer, gpointer, gpointer, gpointer) -> gboolean, transformTo transform_to: @convention(c) @escaping (gpointer, gpointer, gpointer, gpointer) -> gboolean) -> BindingRef! {\n" + tripleIndentation +
                "let holder = UnsafeMutableRawPointer(Unmanaged.passRetained(holder).toOpaque())\n" + tripleIndentation +
                "let from = unsafeBitCast(transform_from, to: BindingTransformFunc.self)\n" + tripleIndentation +
                "let to   = unsafeBitCast(transform_to,   to: BindingTransformFunc.self)\n" + tripleIndentation +
                "let rv = GLibObject.ObjectRef(raw: ptr).bindPropertyFull(sourceProperty: source, target: t, targetProperty: target_property, flags: f, transformTo: to, transformFrom: from, userData: holder) {\n" + tripleIndentation + indentation +
                    "if let swift = UnsafeRawPointer($0) {\n" + tripleIndentation + doubleIndentation +
                        "let holder = Unmanaged<GLibObject.SignalHandlerClosureHolder>.fromOpaque(swift)\n" + tripleIndentation + doubleIndentation +
                        "holder.release()\n" + tripleIndentation + indentation +
                    "}\n" + tripleIndentation +
                "}\n" + tripleIndentation +
                "return rv.map { BindingRef($0) }\n" + doubleIndentation +
            "}\n\n" + doubleIndentation +
            "let rv = _bind(source_property.name, to: target, target_property.name, flags: f, holder: BindingClosureHolder(transform_from, transform_to), transformFrom: {\n" + tripleIndentation +
                "let ptr = UnsafeRawPointer($3)\n" + tripleIndentation +
                "let holder = Unmanaged<BindingClosureHolder>.fromOpaque(ptr).takeUnretainedValue()\n" + tripleIndentation +
                "return holder.transform_from(GLibObject.ValueRef(raw: $1), GLibObject.ValueRef(raw: $2)) ? 1 : 0\n" + doubleIndentation +
        "}) {\n" + tripleIndentation +
            "let ptr = UnsafeRawPointer($3)\n" + tripleIndentation +
            "let holder = Unmanaged<BindingClosureHolder>.fromOpaque(ptr).takeUnretainedValue()\n" + tripleIndentation +
            "return holder.transform_to(GLibObject.ValueRef(raw: $1), GLibObject.ValueRef(raw: $2)) ? 1 : 0\n" + doubleIndentation +
        "}\n" + doubleIndentation +
        "return rv\n" + indentation +
    "}\n\n" + indentation +
    "/// Get the value of a \(className) property\n" + indentation +
    "/// - Parameter property: the property to get the value for\n" + indentation +
    "/// - Returns: the value of the named property\n" + indentation +
    "@inlinable func get(property: \(className)PropertyName) -> GLibObject.Value {\n" + doubleIndentation +
        "let v = GLibObject.Value()\n" + doubleIndentation +
        "g_object_get_property(ptr.assumingMemoryBound(to: GObject.self), property.rawValue, v.value_ptr)\n" + doubleIndentation +
        "return v\n" + indentation +
    "}\n\n" + indentation +
    "/// Set the value of a \(className) property.\n" + indentation +
    "/// *Note* that this will only have an effect on properties that are writable and not construct-only!\n" + indentation +
    "/// - Parameter property: the property to get the value for\n" + indentation +
    "/// - Returns: the value of the named property\n" + indentation +
    "@inlinable func set(property: \(className)PropertyName, value v: GLibObject.Value) {\n" + doubleIndentation +
        "g_object_set_property(ptr.assumingMemoryBound(to: GObject.self), property.rawValue, v.value_ptr)\n" + indentation +
    "}\n}\n\n"))
    let signalEnumCode = (noSignals ? "// MARK: no \(className) signals\n\n" : "public enum \(className)SignalName: String, SignalNameProtocol {\n" +
    //        "public typealias Class = \(protocolName)\n") +
        signals.map(scode.signalNameCode(signal:)).joined(separator: "\n") + "\n" +
        properties.map(ncode.signalNameCode(signal:)).joined(separator: "\n") + "\n}\n\n")
    return code1 + code2 + code3 + signalEnumCode + buildSignalExtension(for: e)
}
