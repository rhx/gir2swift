//
//  File.swift
//  
//
//  Created by Mikoláš Stuchlík on 14.11.2020.
//

import Foundation

func signalCheck(_ signal: GIR.Signal) -> Bool {
    signal.args.allSatisfy { $0.typeRef.type.name != "Void" }
}

func buildSignalExtension(for record: GIR.Record) -> String {
    // Check preconditions
    if record.kind == "Interface" {
        return "// MARK: Signals of \(record.kind) named \(record.name.swift) are dropped"
    }
    
    if record.signals.isEmpty  {
        return "// MARK: no \(record.name.swift) signals"
    }
    
    return Code.block(indentation: nil) {
        
        Code.block {
            Code.loop(over: record.signals.filter({ !signalCheck($0) })) { signal in
                "// Warning: signal \(signal.name) is ignored because of Void argument is not yet supported"
            }
        }

        "// MARK: Signals of \(record.kind) named \(record.name.swift)"
        "public extension \(record.name.swift) {"
        Code.block {
            Code.loop(over: record.signals.filter(signalCheck(_:))) { signal in
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
                    "handler: @escaping ( _ unownedSelf: \(record.structRef.fullSwiftTypeName)"
                    Code.loop(over: signal.args) { argument in
                        ", _ \(argument.prefixedArgumentName): \(argument.typeRef.fullSwiftTypeName)"
                    }
                    ") -> "
                    signal.returns.typeRef.fullSwiftTypeName
                    " ) -> Int {"
                }
                Code.block {
                    "typealias SwiftHandler = \(signalClosureHolderDecl(type: record.structRef.type.swiftName, args: signal.args.map { $0.typeRef.fullSwiftTypeName }, returnType: signal.returns.typeRef.fullSwiftTypeName))"
                    "let swiftHandlerBoxed = Unmanaged.passRetained(SwiftHandler(handler)).toOpaque()"
                    Code.line {
                        "let cCallback: @convention(c) ("
                        "gpointer, "
                        Code.loop(over: signal.args) { argument in
                            "\(argument.typeRef.fullTypeName), "
                        }
                        "gpointer"
                        ") -> "
                        signal.returns.typeRef.fullTypeName
                        " = { "
                    }
                    Code.block {
                        "let holder = Unmanaged<SwiftHandler>.fromOpaque($\(signal.args.count + 1)).takeUnretainedValue()"
                        Code.line {
                            "let output = holder.call(\(record.structRef.type.swiftName)(raw: $0)"
                            Code.loopEnumerated(over: signal.args) { index, argument in
                                ", \(argument.swiftSignalArgumentConversion(at: index + 1))"
                            }
                            ")"
                        }
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

extension GIR.Argument {
    
    func swiftSignalArgumentConversion(at index: Int) -> String {
        if let type = self.knownType as? GIR.Record {
            return type.structRef.fullSwiftTypeName + "(raw: $\(index))"
        }
        
        return "$\(index)"
    }
}

func signalClosureHolderDecl(type: String, args: [String], returnType: String = "Void") -> String {
    let holderType: String
    switch args.count {
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
        fatalError("Argument count \(args.count) exceeds number of allowed arguments (6)")
    }
    
    return holderType
        + "<\(type), "
        + args.joined(separator: ", ")
        + (args.isEmpty ? "" : ", ")
        + returnType
        + ">"
}
