//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 14.11.2020.
//

import Foundation

// TODO: Expand sanity check and add reporting to the code, including ownership and inout
func signalSanityCheck(_ signal: GIR.Signal) -> Bool {
    signal.args.allSatisfy { $0.typeRef.type.name != "Void" }
}

func buildSignalExtension(for record: GIR.Record) -> String {
    // TODO: Add support for generation inside of interface
    if record.kind == "Interface" {
        return "// MARK: Signals of \(record.kind) named \(record.name.swift) are dropped"
    }
    
    if record.signals.isEmpty {
        return "// MARK: no \(record.name.swift) signals"
    }
    
    return Code.block(indentation: nil) {
        
        Code.block {
            Code.loop(over: record.signals.filter({ !signalSanityCheck($0) })) { signal in
                "// Warning: signal \(signal.name) is ignored because of Void argument is not yet supported"
            }
        }

        "// MARK: Signals of \(record.kind) named \(record.name.swift)"
        "public extension \(record.name.swift) {"
        Code.block {
            Code.loop(over: record.signals.filter(signalSanityCheck(_:))) { signal in
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
                        "return \(signal.returns.typeRef.cast(expression: "output", from: signal.returns.swiftReturnRef))"
                    }
                    "}"
                    "let __gCallback__ = unsafeBitCast(cCallback, to: GCallback.self)"
                    "let rv = signalConnectData("
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

private extension GIR.Argument {
    
    func swiftIdiomaticType() -> String {
        switch knownType {
        case let type as GIR.Record: // Also Class, Union, Interface
            return type.structName
        case let type as GIR.Alias: // use containedTypes
            return ""
        case is GIR.Bitfield: // use UInt32
            return self.argumentTypeName
        case is GIR.Enumeration: // Binary integer (use Int)
            return self.argumentTypeName
        default: // Treat as fundamental (if not a fundamental, report error)
            return self.argumentTypeName
        }
    }
    
    func swiftCCompatibleType() -> String {
        switch knownType {
        case is GIR.Record: // Also Class, Union, Interface
            return GIR.gpointerType.typeName
        case let type as GIR.Alias: // use containedTypes
            return ""
        case is GIR.Bitfield: // use UInt32
            return GIR.uint32Type.typeName
        case is GIR.Enumeration: // Binary integer (use Int)
            return GIR.intType.typeName
        default: // Treat as fundamental (if not a fundamental, report error)
            return self.typeRef.fullTypeName
        }
    }
    
    func swiftSignalArgumentConversion(at index: Int) -> String {
        switch knownType {
        case let type as GIR.Record: // Also Class, Union, Interface
            return type.structRef.fullSwiftTypeName + "(raw: $\(index))"
        case let type as GIR.Alias: // use containedTypes
            return ""
        case is GIR.Bitfield: // use UInt32
            return self.argumentTypeName + "($\(index))"
        case is GIR.Enumeration: // Binary integer (use Int)
            return self.argumentTypeName + "($\(index))"
        default: // Treat as fundamental (if not a fundamental, report error)
            return swiftReturnRef.cast(expression: "$\(index)", from: typeRef)
        }
    }
}
