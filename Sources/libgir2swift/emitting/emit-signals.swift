import Foundation

/// This file contains support for signal generation. Since signals are described differently than other function types in .gir files, custom behavior for type generation and casting is implemented.
/// Since the custom generation was already needed, focus of this implementation is safety. If a argument lacks a implementation of safe interface generation, whole signal is ommited. All signals are checked before generation and the decision process was summarized into 9 conditions. The future aim is to lift those limitation progressively. Such feature will require better support from the rest of gir2swift.

/// This method verifies, whether signal is fit to be generated.
/// - Returns: Array of string which contains all the reasons why signal could not be generated. Empty array implies signal is fit to be generated.
func signalSanityCheck(_ signal: GIR.Signal) -> [String] {

    var errors = [String]()
    
    if !signal.args.allSatisfy({ $0.ownershipTransfer == .none }) {
        errors.append("(1) argument with ownership transfer is not allowed")
    }
    
    if !signal.args.allSatisfy({ $0.direction == .in }) {
        errors.append("(2)  `out` or `inout` argument direction is not allowed")
    }

    if !signal.args.allSatisfy({ $0.typeRef.type.name != "Void" }) {
        errors.append("(3)  Void argument is not yet supported")
    }
    
    if !signal.args.allSatisfy({ $0.typeRef.type.name != "gpointer" }) {
        errors.append("(4)  gpointer argument is not yet supported")
    }
    
    if !signal.args.allSatisfy({ !($0.knownType is GIR.Alias) }) || (signal.returns.knownType is GIR.Alias) {
        errors.append("(5)  Alias argument or return is not yet supported")
    }

    if signal.returns.isOptional {
        errors.append("(6)  optional argument or return type is not allowed")
    }

    if !signal.args.allSatisfy({ !$0.isArray }) || signal.returns.isArray {
        errors.append("(7)  array argument or return type is not allowed")
    }

    if signal.returns.isNullable == true {
        errors.append("(8)  nullable argument or return type is not allowed")
    }

    if signal.returns.knownType is GIR.Record {
        errors.append("(9)  Record return type is not yet supported")
    }

    return errors
}

func buildSignalExtension(for record: GIR.Record) -> String {
    let recordName = record.name.swift
    let signalType = recordName + "SignalName"

    if record.signals.isEmpty {
        return "// MARK: \(record.name.swift) has no signals\n"
    }
    
    return Code.block(indentation: nil) {
        
        "// MARK: \(recordName) signals"
        "public extension \(record.protocolName) {"

        Code.block {
            "/// Connect a Swift signal handler to the given, typed `\(signalType)` signal"
            "/// - Parameters:"
            "///   - signal: The signal to connect"
            "///   - flags: The connection flags to use"
            "///   - data: A pointer to user data to provide to the callback"
            "///   - destroyData: A `GClosureNotify` C function to destroy the data pointed to by `userData`"
            "///   - handler: The Swift signal handler (function or callback) to invoke on the given signal"
            "/// - Returns: The signal handler ID (always greater than 0 for successful connections)"
            "@inlinable @discardableResult func connect(signal s: \(signalType), flags f: ConnectFlags = ConnectFlags(0), handler h: @escaping SignalHandler) -> Int {"
            Code.block {
                "\(record is GIR.Interface ? "GLibObject.ObjectRef(raw: ptr)." : "" )connect(s, flags: f, handler: h)"
            }
            "}\n\n"

            "/// Connect a C signal handler to the given, typed `\(signalType)` signal"
            "/// - Parameters:"
            "///   - signal: The signal to connect"
            "///   - flags: The connection flags to use"
            "///   - data: A pointer to user data to provide to the callback"
            "///   - destroyData: A `GClosureNotify` C function to destroy the data pointed to by `userData`"
            "///   - signalHandler: The C function to be called on the given signal"
            "/// - Returns: The signal handler ID (always greater than 0 for successful connections)"
            "@inlinable @discardableResult func connect(signal s: \(signalType), flags f: ConnectFlags = ConnectFlags(0), data userData: gpointer!, destroyData destructor: GClosureNotify? = nil, signalHandler h: @escaping GCallback) -> Int {"
            Code.block {
                (record is GIR.Interface ? "GLibObject.ObjectRef(raw: ptr)." : "") +
                "connectSignal(s, flags: f, data: userData, destroyData: destructor, handler: h)"
            }
            "}\n\n"

            // Generation of unavailable signals
            Code.loop(over: record.signals.filter( {!signalSanityCheck($0).isEmpty} )) { signal in
                buildUnavailableSignal(record: record, signal: signal)
            }
            // Generation of available signals
            Code.loop(over: record.signals.filter( {signalSanityCheck($0).isEmpty } )) { signal in
                buildAvailableSignal(record: record, signal: signal)
            }
            // Generation of property obsevers. Property observers have the same delcaration as GObject signal `notify`. This sinal should be available at all times.
            if let notifySignal = GIR.knownRecords["Object"]?.signals.first(where: { $0.name == "notify"}) {
                Code.loop(over: record.properties) { property in
                    buildSignalForProperty(record: record, property: property, notify: notifySignal)
                }
            } else {
                "// \(recordName) property signals were not generated due to unavailability of GObject during generation time"
            }
            
        }
        "}\n\n"
    }
}

/// Modifies provided signal model to notify about property change.
/// - Parameter record: Record of the property
/// - Parameter property: Property which observer will be genrated
/// - Parameter notify: GObject signal "notify" which is basis for the signal generation.
private func buildSignalForProperty(record: GIR.Record, property: GIR.Property, notify: GIR.Signal) -> String {
    let propertyNotify = GIR.Signal(
        name: notify.name + "::" + property.name,
        cname: notify.cname,
        returns: notify.returns,
        args: notify.args,
        comment: notify.comment,
        introspectable: notify.introspectable,
        deprecated: notify.deprecated,
        throwsAnError: notify.throwsError
    )
    
    return buildAvailableSignal(record: record, signal: propertyNotify)
}

@CodeBuilder
private func buildAvailableSignal(record: GIR.Record, signal: GIR.Signal) -> String {
    addDocumentation(signal: signal)

    let recordName = record.name.swift
    let signalType = recordName + "SignalName"
    let swiftSignal = signal.name.replacingOccurrences(of: "::", with: "_").kebabSnakeCase2camelCase

    "/// Run the given callback whenever the `\(swiftSignal)` signal is emitted"
    Code.line {
        "@discardableResult @inlinable func on\(swiftSignal.capitalised)("
        "flags: ConnectFlags = ConnectFlags(0), "
        "handler: "
        handlerType(record: record, signal: signal)
        " ) -> Int {"
    }
    Code.block {
        "typealias SwiftHandler = \(signalClosureHolderDecl(record: record, signal: signal))"
        Code.line {
            "let cCallback: "
            cCallbackDecl(record: record, signal: signal)
            " = { "
            cCallbackArgumentsDecl(record: record, signal: signal)
            " in"
        }
        Code.block {
            "let holder = Unmanaged<SwiftHandler>.fromOpaque(userData).takeUnretainedValue()"
            "let output\(signal.returns.typeRef.type.name == "Void" ? ": Void" : "") = holder.\(generaceCCallbackCall(record: record, signal: signal))"
            generateReturnStatement(record: record, signal: signal)
        }
        "}"
        "return connect("
        Code.block {
            "signal: .\(swiftSignal),"
            "flags: flags,"
            "data: Unmanaged.passRetained(SwiftHandler(handler)).toOpaque(),"
            "destroyData: { userData, _ in UnsafeRawPointer(userData).flatMap(Unmanaged<SwiftHandler>.fromOpaque(_:))?.release() },"
            "signalHandler: unsafeBitCast(cCallback, to: GCallback.self)"
        }
        ")"
    }
    "}\n"
    "/// Typed `\(signal.name)` signal for using the `connect(signal:)` methods"
    "static var \(swiftSignal)Signal: \(signalType) { .\(swiftSignal) }\n"
}

/// This function build documentation and name for unavailable signal.
@CodeBuilder
private func buildUnavailableSignal(record: GIR.Record, signal: GIR.Signal) -> String {
    addDocumentation(signal: signal)

    let recordName = record.name.swift
    let signalType = recordName + "SignalName"
    let swiftSignal = signal.name.replacingOccurrences(of: "::", with: "_").kebabSnakeCase2camelCase

    "/// - Warning: a `on\(swiftSignal.capitalised)` wrapper for this signal could not be generated because it contains unimplemented features: { \( signalSanityCheck(signal).joined(separator: ", ") ) }"
    "/// - Note: Instead, you can connect `\(swiftSignal)Signal` using the `connect(signal:)` methods"
    "static var \(swiftSignal)Signal: \(signalType) { .\(swiftSignal) }"
}

/// This function build Swift closure handler declaration.
@CodeBuilder
private func handlerType(record: GIR.Record, signal: GIR.Signal) -> String {
    "@escaping ( _ unownedSelf: \(record.structName)"
    Code.loop(over: signal.args) { argument in
        ", _ \(argument.prefixedArgumentName): \(argument.swiftIdiomaticType())"
    }
    ") -> "
    signal.returns.swiftIdiomaticType()
}

/// This function builds declaration for the typealias holding the reference to the Swift closure handler
private func signalClosureHolderDecl(record: GIR.Record, signal: GIR.Signal) -> String {
    if signal.args.count > 6 {
        fatalError("Argument count \(signal.args.count) exceeds the maximum number of allowed arguments (6)")
    }
    return Code.line {
        "GLib.ClosureHolder" + (signal.args.count > 0 ? "\(signal.args.count + 1)" : "")
        "<" + record.structName + ", "
        signal.args.map { $0.swiftIdiomaticType() }.joined(separator: ", ")
        (signal.args.isEmpty ? "" : ", ")
        signal.returns.swiftIdiomaticType()
        ">"
    }
}

/// This function adds Parameter documentation to the signal on top of existing documentation generation.
@CodeBuilder
private func addDocumentation(signal: GIR.Signal) -> String {
    { str -> String in str.isEmpty ? CodeBuilder.ignoringEspace : str}(commentCode(signal))
    "/// - Note: This represents the underlying `\(signal.name)` signal"
    "/// - Parameter flags: Flags"
    "/// - Parameter unownedSelf: Reference to instance of self"
    Code.loop(over: signal.args) { argument in
        let comment = gtkDoc2SwiftDoc(argument.comment, linePrefix: "").replacingOccurrences(of: "\n", with: " ")
        "/// - Parameter \(argument.prefixedArgumentName): \(comment.isEmpty ? "none" : comment)"
    }
    let returnComment = gtkDoc2SwiftDoc(signal.returns.comment, linePrefix: "").replacingOccurrences(of: "\n", with: " ")
    "/// - Parameter handler: \(returnComment.isEmpty ? "The signal handler to call" : returnComment)"
}

/// Returns declaration for c callback.
@CodeBuilder
private func cCallbackDecl(record: GIR.Record, signal: GIR.Signal) -> String {
    "@convention(c) ("
    GIR.gpointerType.typeName + ", "            // Representing record itself
    Code.loop(over: signal.args) { argument in
        argument.swiftCCompatibleType() + ", "
    }
    GIR.gpointerType.typeName                   // Representing user data
    ") -> "
    signal.returns.swiftCCompatibleType()
}

/// list of names of arguments of c callback
private func cCallbackArgumentsDecl(record: GIR.Record, signal: GIR.Signal) -> String {
    Code.line {
        "unownedSelf"
        Code.loopEnumerated(over: signal.args) { index, _ in
            ", arg\(index + 1)"
        }
        ", userData"
    }
}

/// Returns correct call of Swift handler from c callback scope with correct casting.
private func generaceCCallbackCall(record: GIR.Record, signal: GIR.Signal) -> String {
    Code.line {
        "call(\(record.structRef.type.swiftName)(raw: unownedSelf)"
        Code.loopEnumerated(over: signal.args) { index, argument in
            ", \(argument.swiftSignalArgumentConversion(at: index + 1))"
        }
        ")"
    }
}

/// Generates correct return statement. This method currently contains implementation of ownership-transfer ability for String.
private func generateReturnStatement(record: GIR.Record, signal: GIR.Signal) -> String {
    switch signal.returns.knownType {
    case is GIR.Record:
        return "return \(signal.returns.typeRef.cast(expression: "output", from: signal.returns.swiftSignalRef))"
    case is GIR.Alias: // use containedTypes
        return ""
    case is GIR.Bitfield:
        return "return output.rawValue"
    case is GIR.Enumeration:
        return "return output.rawValue"
    case nil where signal.returns.swiftSignalRef == GIR.stringRef && signal.returns.ownershipTransfer == .full:
        return Code.block {
            "let length = output.utf8CString.count"
            "let buffer = UnsafeMutablePointer<gchar>.allocate(capacity: length)"
            "buffer.initialize(from: output, count: length)"
            "return buffer"
        }
    default: // Treat as fundamental (if not a fundamental, report error)
        return "return \(signal.returns.typeRef.cast(expression: "output", from: signal.returns.swiftSignalRef))"
    }
}

private extension GIR.Argument {
    
    /// Returns type names for Swift adjusted for the needs of signal generation
    func swiftIdiomaticType() -> String {
        switch knownType {
        case is GIR.Record:
            return typeRef.type.swiftName + "Ref" + ((isNullable || isOptional) ? "?" : "")
        case is GIR.Alias: // use containedTypes
            return ""
        case is GIR.Bitfield:
            return self.argumentTypeName + ((isNullable || isOptional) ? "?" : "")
        case is GIR.Enumeration:
            return self.argumentTypeName + ((isNullable || isOptional) ? "?" : "")
        default: // Treat as fundamental (if not a fundamental, report error)
            return self.swiftSignalRef.fullSwiftTypeName + ((isNullable || isOptional) ? "?" : "")
        }
    }

    /// Returns names name for C adjusted for the needs of signal generation
    func swiftCCompatibleType() -> String {
        switch knownType {
        case is GIR.Record:
            return GIR.gpointerType.typeName + ((isNullable || isOptional) ? "?" : "")
        case is GIR.Alias: // use containedTypes
            return ""
        case is GIR.Bitfield:
            return GIR.uint32Type.typeName + ((isNullable || isOptional) ? "?" : "")
        case is GIR.Enumeration:
            return GIR.uint32Type.typeName + ((isNullable || isOptional) ? "?" : "")
        default: // Treat as fundamental (if not a fundamental, report error)
            return self.callbackArgumentTypeName
        }
    }

    /// Generates correct cast from C type/argument to Swift type. This method currently supports optionals.
    func swiftSignalArgumentConversion(at index: Int) -> String {
        switch knownType {
        case is GIR.Record:
            if (isNullable || isOptional) {
                return "arg\(index).flatMap(\(typeRef.type.swiftName)Ref.init(raw:))"
            }
            return typeRef.type.swiftName + "Ref" + "(raw: arg\(index))"
        case is GIR.Alias: // use containedTypes
            return ""
        case is GIR.Bitfield:
            if (isNullable || isOptional) {
                return "arg\(index).flatMap(\(self.argumentTypeName).init(_:))"
            }
            return self.argumentTypeName + "(arg\(index))"
        case is GIR.Enumeration:
            if (isNullable || isOptional) {
                return "arg\(index).flatMap(\(self.argumentTypeName).init(_:))"
            }
            return self.argumentTypeName + "(arg\(index))"
        case nil where swiftSignalRef == GIR.stringRef:
            return swiftSignalRef.cast(expression: "arg\(index)", from: typeRef) + ((isNullable || isOptional) ? "" : "!")
        default: // Treat as fundamental (if not a fundamental, report error)
            return swiftSignalRef.cast(expression: "arg\(index)", from: typeRef)
        }
    }
}
