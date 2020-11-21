//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 14.11.2020.
//

import Foundation

func signalSanityCheck(_ signal: GIR.Signal) -> [String] {

    var errors = [String]()
    
    if !signal.args.allSatisfy({ $0.ownershipTransfer == .none }) {
        errors.append("(1) argument with owner transfership is not allowed")
    }
    
    if !signal.args.allSatisfy({ $0.direction == .in }) {
        errors.append("(2)  argument out or inout direction is not allowed")
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
        errors.append("(6)  argument or return optional is not allowed")
    }

    if !signal.args.allSatisfy({ !$0.isArray }) || signal.returns.isArray {
        errors.append("(7)  argument or return array is not allowed")
    }

    if signal.returns.isNullable == true {
        errors.append("(8)  argument or return nullability is not allowed")
    }

    if signal.returns.knownType is GIR.Record {
        errors.append("(9)  Record return is not yet supported")
    }

    return errors
}

func buildSignalExtension(for record: GIR.Record) -> String {

    if record.signals.isEmpty {
        return "// MARK: \(record.name.swift) has no signals"
    }
    
    return Code.block(indentation: nil) {
        
        "// MARK: Signals of \(record.name.swift)"
        "public extension \(record.protocolName) {"
        Code.block {
            Code.loop(over: record.signals.filter( {!signalSanityCheck($0).isEmpty} )) { signal in
                buildUnavailable(signal: signal)
            }
            Code.loop(over: record.signals.filter( {signalSanityCheck($0).isEmpty } )) { signal in
                buildAvailableSignal(record: record, signal: signal)
            }
            if let notifySignal = GIR.knownRecords["Object"]?.signals.first(where: { $0.name == "notify"}) {
                Code.loop(over: record.properties) { property in
                    buildSignalForProperty(record: record, property: property, notify: notifySignal)
                }
            } else {
                "// Signals of properites were not generated due to unavailability of GObject during generation time"
            }
            
        }
        "}\n\n"
    }
}

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
    
    "@discardableResult"
    Code.line {
        "func on\(signal.name.replacingOccurrences(of: "::", with: "_").camelSignal.capitalised)("
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
        "return \(record is GIR.Interface ? "GLibObject.ObjectRef(raw: ptr)." : "" )signalConnectData("
        Code.block {
            #"detailedSignal: "\#(signal.name)", "#
            "cHandler: unsafeBitCast(cCallback, to: GCallback.self), "
            "data: Unmanaged.passRetained(SwiftHandler(handler)).toOpaque(), "
            "destroyData: { userData, _ in UnsafeRawPointer(userData).flatMap(Unmanaged<SwiftHandler>.fromOpaque(_:))?.release() },"
            "connectFlags: flags"
        }
        ")"
    }
    "}\n"
}

@CodeBuilder
private func buildUnavailable(signal: GIR.Signal) -> String {
    addDocumentation(signal: signal)
    "/// - Warning: Wrapper of this signal could not be generated because it contains unimplemented features: { \( signalSanityCheck(signal).joined(separator: ", ") ) }"
    "/// - Note: Use this string for `signalConnectData` method"
    #"static var on\#(signal.name.camelSignal.capitalised): String { "\#(signal.name)" }"#
}

@CodeBuilder
private func handlerType(record: GIR.Record, signal: GIR.Signal) -> String {
    "@escaping ( _ unownedSelf: \(record.structName)"
    Code.loop(over: signal.args) { argument in
        ", _ \(argument.prefixedArgumentName): \(argument.swiftIdiomaticType())"
    }
    ") -> "
    signal.returns.swiftIdiomaticType()
}

private func signalClosureHolderDecl(record: GIR.Record, signal: GIR.Signal) -> String {
    if signal.args.count > 6 {
        fatalError("Argument count \(signal.args.count) exceeds number of allowed arguments (6)")
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

@CodeBuilder
private func addDocumentation(signal: GIR.Signal) -> String {
    { str -> String in str.isEmpty ? CodeBuilder.ignoringEspace : str}(commentCode(signal))
    "/// - Note: Representation of signal named `\(signal.name)`"
    "/// - Parameter flags: Flags"
    let returnComment = gtkDoc2SwiftDoc(signal.returns.comment, linePrefix: "").replacingOccurrences(of: "\n", with: " ")
    if !returnComment.isEmpty {
        "/// - Parameter handler: \(returnComment)"
    }

    "/// - Parameter unownedSelf: Reference to instance of self"
    Code.loop(over: signal.args) { argument in
        let comment = gtkDoc2SwiftDoc(argument.comment, linePrefix: "").replacingOccurrences(of: "\n", with: " ")
        "/// - Parameter \(argument.prefixedArgumentName): \(comment.isEmpty ? "none" : comment)"
    }
}

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

private func cCallbackArgumentsDecl(record: GIR.Record, signal: GIR.Signal) -> String {
    Code.line {
        "unownedSelf"
        Code.loopEnumerated(over: signal.args) { index, _ in
            ", arg\(index + 1)"
        }
        ", userData"
    }
}

private func generaceCCallbackCall(record: GIR.Record, signal: GIR.Signal) -> String {
    Code.line {
        "call(\(record.structRef.type.swiftName)(raw: unownedSelf)"
        Code.loopEnumerated(over: signal.args) { index, argument in
            ", \(argument.swiftSignalArgumentConversion(at: index + 1))"
        }
        ")"
    }
}

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
