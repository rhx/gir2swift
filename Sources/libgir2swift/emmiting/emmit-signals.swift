//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 14.11.2020.
//

import Foundation

func signalSanityCheck(_ signal: GIR.Signal) -> String? {
    if !signal.args.allSatisfy({ $0.typeRef.type.name != "Void" }) {
        return "// Warning: signal \(signal.name) is ignored because of Void argument is not yet supported"
    }
    
    if !signal.args.allSatisfy({ !($0.knownType is GIR.Alias) }) || (signal.returns.knownType is GIR.Alias) {
        return "// Warning: signal \(signal.name) is ignored because of Alias argument or return is not yet supported"
    }
    
    if !signal.args.allSatisfy({ $0.ownershipTransfer == .none }) || signal.returns.ownershipTransfer != .none {
        return "// Warning: signal \(signal.name) is ignored because of argument or return with owner transfership is not allowed"
    }

    if !signal.args.allSatisfy({ !$0.isOptional }) || signal.returns.isOptional {
        return "// Warning: signal \(signal.name) is ignored because of argument or return optional is not allowed"
    }

    if !signal.args.allSatisfy({ $0.typeRef.type.name != "utf8" }) || signal.returns.typeRef.type.name == "utf8" {
        return "// Warning: signal \(signal.name) is ignored because of argument or return String is not allowed"
    }
    
    if !signal.args.allSatisfy({ $0.isNullable == false }) || signal.returns.isNullable == true {
        return "// Warning: signal \(signal.name) is ignored because of argument or return nullability is not allowed"
    }

    if signal.returns.knownType is GIR.Record {
        return "// Warning: signal \(signal.name) is ignored because of Record return is not yet supported"
    }

    return nil
}

func buildSignalExtension(for record: GIR.Record) -> String {

    if record.signals.isEmpty {
        return "// MARK: no \(record.name.swift) signals"
    }
    
    return Code.block(indentation: nil) {
        
        "// MARK: Signals of \(record.kind) named \(record.name.swift)"

        Code.block {
            Code.loop(over: record.signals.compactMap({ signalSanityCheck($0) })) { error in
                "\(error)"
            }
        }

        "public extension \(record.name.swift) {"
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
                    "let swiftHandlerBoxed = Unmanaged.passRetained(SwiftHandler(handler)).toOpaque()"
                    Code.line {
                        "let cCallback: "
                        cCallbackDecl(record: record, signal: signal)
                        " = { "
                    }
                    Code.block {
                        "let holder = Unmanaged<SwiftHandler>.fromOpaque($\(signal.args.count + 1)).takeUnretainedValue()"
                        "let output = holder.\(generaceCCallbackCall(record: record, signal: signal))"
                        generateReturnStatement(record: record, signal: signal)
                    }
                    "}"
                    "let __gCallback__ = unsafeBitCast(cCallback, to: GCallback.self)"
                    Code.line {
                        "let rv = "
                        if record is GIR.Interface {
                            "GLibObject.ObjectRef(raw: ptr)."
                        }
                        "signalConnectData("
                    }
                    Code.block {
                        #"detailedSignal: "\#(signal.name)", "#
                        "cHandler: __gCallback__, "
                        "data: swiftHandlerBoxed, "
                        "destroyData: {"
                        Code.block {
                            "if let swift = $0 {"
                            Code.block {
                                "let holder = Unmanaged<SwiftHandler>.fromOpaque(swift)"
                                "holder.release()"
                            }
                            "}"
                            "let _ = $1"
                        }
                        "}, "
                        "connectFlags: flags"
                    }
                    ")"
                    "return rv"
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

private func generaceCCallbackCall(record: GIR.Record, signal: GIR.Signal) -> String {
    Code.line {
        "call(\(record.structRef.type.swiftName)(raw: $0)"
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
    case let type as GIR.Alias: // use containedTypes
        return ""
    case is GIR.Bitfield:
        return "return output.rawValue"
    case is GIR.Enumeration:
        return "return output.rawValue"
    default: // Treat as fundamental (if not a fundamental, report error)
        return "return \(signal.returns.typeRef.cast(expression: "output", from: signal.returns.swiftReturnRef))"
    }
}

private extension GIR.Argument {
    
    func swiftIdiomaticType() -> String {
        switch knownType {
        case is GIR.Record:
            return typeRef.type.swiftName + "Ref"
        case let type as GIR.Alias: // use containedTypes
            return ""
        case is GIR.Bitfield:
            return self.argumentTypeName
        case is GIR.Enumeration:
            return self.argumentTypeName
        default: // Treat as fundamental (if not a fundamental, report error)
            return self.argumentTypeName
        }
    }
    
    func swiftCCompatibleType() -> String {
        switch knownType {
        case is GIR.Record:
            return GIR.gpointerType.typeName
        case let type as GIR.Alias: // use containedTypes
            return ""
        case is GIR.Bitfield:
            return GIR.uint32Type.typeName
        case is GIR.Enumeration:
            return GIR.uint32Type.typeName
        default: // Treat as fundamental (if not a fundamental, report error)
            return self.typeRef.fullTypeName
        }
    }
    
    func swiftSignalArgumentConversion(at index: Int) -> String {
        switch knownType {
        case is GIR.Record:
            return typeRef.type.swiftName + "Ref" + "(raw: $\(index))"
        case let type as GIR.Alias: // use containedTypes
            return ""
        case is GIR.Bitfield:
            return self.argumentTypeName + "($\(index))"
        case is GIR.Enumeration:
            return self.argumentTypeName + "($\(index))"
        default: // Treat as fundamental (if not a fundamental, report error)
            return swiftReturnRef.cast(expression: "$\(index)", from: typeRef)
        }
    }
}
