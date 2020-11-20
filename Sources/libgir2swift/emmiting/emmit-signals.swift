//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 14.11.2020.
//

import Foundation

func signalSanityCheck(_ signal: GIR.Signal) -> String? {

    var errors: String?
    
    if !signal.args.allSatisfy({ $0.ownershipTransfer == .none }) {
        errors = (errors ?? "") + " (1) argument with owner transfership is not allowed;"
    }
    
    if !signal.args.allSatisfy({ $0.direction == .in }) {
        errors = (errors ?? "") + " (2)  argument out or inout direction is not allowed;"
    }

    if !signal.args.allSatisfy({ $0.typeRef.type.name != "Void" }) {
        errors = (errors ?? "") + " (3)  Void argument is not yet supported;"
    }
    
    if !signal.args.allSatisfy({ $0.typeRef.type.name != "gpointer" }) {
        errors = (errors ?? "") + " (3.1)  gpointer argument is not yet supported;"
    }
    
    if !signal.args.allSatisfy({ !($0.knownType is GIR.Alias) }) || (signal.returns.knownType is GIR.Alias) {
        errors = (errors ?? "") + " (4)  Alias argument or return is not yet supported;"
    }

    if signal.returns.isOptional {
        errors = (errors ?? "") + " (5)  argument or return optional is not allowed;"
    }

    if !signal.args.allSatisfy({ !$0.isArray }) || signal.returns.isArray {
        errors = (errors ?? "") + " (6)  argument or return array is not allowed;"
    }

    if signal.returns.isNullable == true {
        errors = (errors ?? "") + " (7)  argument or return nullability is not allowed;"
    }

    if signal.returns.knownType is GIR.Record {
        errors = (errors ?? "") + " (8)  Record return is not yet supported;"
    }

    return errors.flatMap { "// Warning: signal \(signal.name) is ignored because of" + $0 }
}

func buildSignalExtension(for record: GIR.Record) -> String {

    if record.signals.isEmpty {
        return "// MARK: no \(record.name.swift) signals"
    }
    
    return Code.block(indentation: nil) {
        
        "// MARK: Signals of \(record.name.swift)"

        Code.block {
            Code.loop(over: record.signals.compactMap({ signalSanityCheck($0) })) { error in
                "\(error)"
            }
        }

        "public extension \(record.protocolName) {"
        Code.block {
            Code.loop(over: record.signals.filter { signalSanityCheck($0) == nil }) { signal in

                commentCode(signal)
                "/// - Note: This function represents signal `\(signal.name)`"
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
                Code.line {
                    "public func _on\(signal.name.camelSignal.capitalised)("
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
                        "let output = holder.\(generaceCCallbackCall(record: record, signal: signal))"
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
                "}"
                "\n"
            }
        }
        "}"
        "\n\n"
    }
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
    let holderType: String
    switch signal.args.count {
    case 0:
        holderType = "Tmp__ClosureHolder"
    case 1:
        holderType = "Tmp__DualClosureHolder"
    case 2:
        holderType = "Tmp__Closure3Holder"
    case 3:
        holderType = "Tmp__Closure4Holder"
    case 4:
        holderType = "Tmp__Closure5Holder"
    case 5:
        holderType = "Tmp__Closure6Holder"
    case 6:
        holderType = "Tmp__Closure7Holder"
    default:
        fatalError("Argument count \(signal.args.count) exceeds number of allowed arguments (6)")
    }
    
    return holderType
        + "<" + record.structName + ", "
        + signal.args.map { $0.swiftIdiomaticType() }.joined(separator: ", ")
        + (signal.args.isEmpty ? "" : ", ")
        + signal.returns.swiftIdiomaticType()
        + ">"
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
        return "return \(signal.returns.typeRef.cast(expression: "output", from: signal.returns.swiftReturnRef))"
    case is GIR.Alias: // use containedTypes
        return ""
    case is GIR.Bitfield:
        return "return output.rawValue"
    case is GIR.Enumeration:
        return "return output.rawValue"
    case nil where signal.returns.swiftReturnRef == GIR.stringRef && signal.returns.ownershipTransfer == .full:
        return Code.block {
            "let length = output.utf8CString.count"
            "let buffer = UnsafeMutablePointer<gchar>.allocate(capacity: length)"
            "buffer.initialize(from: output, count: length)"
            "return buffer"
        }
    default: // Treat as fundamental (if not a fundamental, report error)
        return "return \(signal.returns.typeRef.cast(expression: "output", from: signal.returns.swiftReturnRef))"
    }
}

private extension GIR.Argument {
    
    func swiftIdiomaticType() -> String {
        switch knownType {
        case is GIR.Record:
            return typeRef.type.swiftName + "Ref" + (isNullable ? "?" : "")
        case is GIR.Alias: // use containedTypes
            return ""
        case is GIR.Bitfield:
            return self.argumentTypeName + (isNullable ? "?" : "")
        case is GIR.Enumeration:
            return self.argumentTypeName + (isNullable ? "?" : "")
        default: // Treat as fundamental (if not a fundamental, report error)
            return self.swiftReturnRef.fullSwiftTypeName + (isNullable ? "?" : "")
        }
    }
    
    func swiftCCompatibleType() -> String {
        switch knownType {
        case is GIR.Record:
            return GIR.gpointerType.typeName + (isNullable ? "?" : "")
        case is GIR.Alias: // use containedTypes
            return ""
        case is GIR.Bitfield:
            return GIR.uint32Type.typeName + (isNullable ? "?" : "")
        case is GIR.Enumeration:
            return GIR.uint32Type.typeName + (isNullable ? "?" : "")
        default: // Treat as fundamental (if not a fundamental, report error)
            return self.callbackArgumentTypeName
        }
    }
    
    func swiftSignalArgumentConversion(at index: Int) -> String {
        switch knownType {
        case is GIR.Record:
            if isNullable {
                return "arg\(index).flatMap(\(typeRef.type.swiftName)Ref.init(raw:))"
            }
            return typeRef.type.swiftName + "Ref" + "(raw: arg\(index))"
        case is GIR.Alias: // use containedTypes
            return ""
        case is GIR.Bitfield:
            if isNullable {
                return "arg\(index).flatMap(\(self.argumentTypeName).init(_:))"
            }
            return self.argumentTypeName + "(arg\(index))"
        case is GIR.Enumeration:
            if isNullable {
                return "arg\(index).flatMap(\(self.argumentTypeName).init(_:))"
            }
            return self.argumentTypeName + "(arg\(index))"
        case nil where swiftReturnRef == GIR.stringRef:
            return swiftReturnRef.cast(expression: "arg\(index)", from: typeRef) + (isNullable ? "" : "!")
        default: // Treat as fundamental (if not a fundamental, report error)
            return swiftReturnRef.cast(expression: "arg\(index)", from: typeRef)
        }
    }
}
