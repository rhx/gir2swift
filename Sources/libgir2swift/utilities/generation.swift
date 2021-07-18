//
//  generation.swift
//  gir2swift
//
//  Created by Rene Hexel on 20/5/2021.
//  Copyright © 2016, 2017, 2018, 2019, 2020, 2021 Rene Hexel. All rights reserved.
//
import Foundation
import Dispatch

private extension String {
    func nonEmptyComponents<S: StringProtocol>(separatedBy separator: S) -> [String] {
        components(separatedBy: separator).filter { !$0.isEmpty }
    }
}

/// load a GIR file, then invoke the processing closure
private func load_gir(_ file: String, quiet q: Bool = false, process: (GIR) -> Void =  { _ in }) {
    do {
        try Data(contentsOf: URL(fileURLWithPath: file), options: .alwaysMapped).withUnsafeBytes { bytes in
            guard let gir = GIR(buffer: bytes.bindMemory(to: CChar.self), quiet: q) else {
                print("Error: Cannot parse GIR file '\(file)'", to: &Streams.stdErr)
                return
            }
            if gir.prefix.isEmpty {
                print("Warning: no namespace in GIR file '\(file)'", to: &Streams.stdErr)
            }
            process(gir);
        }
    } catch {
        print("Error: Failed to open '\(file)' \(error)", to: &Streams.stdErr)
    }
}

/// process blacklist and verbatim constants information
private func processSpecialCases(_ gir: GIR, forFile node: String) {
    let preamble = node + ".preamble"
    gir.preamble = (try? String(contentsOfFile: preamble)) ?? ""
    let blacklist = node + ".blacklist"
    GIR.blacklist = (try? String(contentsOfFile: blacklist)).flatMap { Set($0.nonEmptyComponents(separatedBy: "\n")) } ?? []
    let verbatimConstants = node + ".verbatim"
    GIR.verbatimConstants = (try? String(contentsOfFile: verbatimConstants)).flatMap { Set($0.nonEmptyComponents(separatedBy: "\n")) } ?? []
    let overrideFile = node + ".override"
    GIR.overrides = (try? String(contentsOfFile: overrideFile)).flatMap { Set($0.nonEmptyComponents(separatedBy: "\n")) } ?? []
}

extension Gir2Swift {

    /// pre-load a GIR without processing, but adding to known types / records
    func preload_gir(file: String) {
        load_gir(file, quiet: true)
    }

    /// process a GIR file
    func process_gir(file: String, boilerPlate modulePrefix: String, to outputDirectory: String? = nil, split singleFilePerClass: Bool = false, generateAll: Bool = false, useAlphaNames: Bool = false) {
        let node = file.components(separatedBy: "/").last?.stringByRemoving(suffix: ".gir") ?? file
        let wlfile = node + ".whitelist"
        if let whitelist = (try? String(contentsOfFile: wlfile)).flatMap({ Set($0.nonEmptyComponents(separatedBy: "\n")) }) {
            for name in whitelist {
                GIR.knownDataTypes.removeValue(forKey: name)
                GIR.knownRecords.removeValue(forKey: name)
                GIR.KnownFunctions.removeValue(forKey: name)
            }
        }
        let escfile = node + ".callbackSuffixes"
        GIR.callbackSuffixes = (try? String(contentsOfFile: escfile))?.nonEmptyComponents(separatedBy: "\n") ?? [
            "Notify", "Func", "Marshaller", "Callback"
        ]
        let nsfile = node + ".namespaceReplacements"
        if let ns = (try? String(contentsOfFile: nsfile)).flatMap({Set($0.nonEmptyComponents(separatedBy: "\n"))}) {
            for line in ns {
                let keyValues: [Substring]
                let tabbedKeyValues: [Substring] = line.split(separator: "\t")
                if tabbedKeyValues.count >= 2 {
                    keyValues = tabbedKeyValues
                } else {
                    keyValues = line.split(separator: " ")
                    guard keyValues.count >= 2 else { continue }
                }
                let key = keyValues[0]
                let value = keyValues[1]
                GIR.namespaceReplacements[key] = value
            }
        }
        let fileManager = FileManager.default

        load_gir(file) { gir in
            processSpecialCases(gir, forFile: node)
            let blacklist = GIR.blacklist
            let boilerplate = gir.boilerPlate
            let preamble = gir.preamble
            let modulePrefix = modulePrefix + boilerplate
            let queues = DispatchGroup()
            let background = DispatchQueue.global()
            let alphaq = useAlphaNames ? DispatchQueue(label: "com.github.rhx.gir2swift.recordqueue") : background
            let outq = DispatchQueue(label: "com.github.rhx.gir2swift.outputqueue")
            if outputDirectory == nil { print(modulePrefix + preamble) }

            func write(_ string: String, to fileName: String, preamble: String = gir.preamble) {
                do {
                    if fileManager.fileExists(atPath: fileName) {
                        let oldContent = try String(contentsOfFile: fileName, encoding: .utf8)
                        let newContent = oldContent + string
                        try newContent.write(toFile: fileName, atomically: true, encoding: .utf8)
                    } else {
                        let newContent = preamble + string
                        try newContent.write(toFile: fileName, atomically: true, encoding: .utf8)
                    }
                } catch {
                    outq.async(group: queues) { print("\(error)", to: &Streams.stdErr) }
                }
            }
            func writebg(queue: DispatchQueue = background, _ string: String, to fileName: String) {
                queue.async(group: queues) { write(string, to: fileName) }
            }
            func write<T: GIR.Record>(_ types: [T], using ptrconvert: (String) -> (GIR.Record) -> String) {
                if let dir = outputDirectory {
                    writebg(modulePrefix, to: "\(dir)/\(node).swift")
                    var output = ""
                    var first: Character? = nil
                    var firstName = ""
                    var name = ""
                    for type in types {
                        let convert = ptrconvert(type.ptrName)
                        let code = convert(type)
                        
                        output += code + "\n\n"
                        name = type.className
                        guard let firstChar = name.first else { continue }
                        let f: String
                        if useAlphaNames {
                            name = firstChar.isASCII && firstChar.isLetter ? type.className.upperInitial : "@"
                            guard first != nil && first != firstChar else {
                                if first == nil {
                                    first = firstChar
                                    firstName = name
                                }
                                continue
                            }
                            f = "\(dir)/\(node)-\(firstName).swift"
                        } else {
                            guard singleFilePerClass || ( first != nil && first != firstChar ) else {
                                if first == nil {
                                    first = firstChar
                                    firstName = name + "-"
                                }
                                continue
                            }
                            f = "\(dir)/\(node)-\(firstName)\(name).swift"
                        }
                        writebg(queue: alphaq, output, to: f)
                        output = ""
                        first = nil
                    }
                    if first != nil {
                        let f = "\(dir)/\(node)-\(firstName)\(useAlphaNames ? "" : name).swift"
                        writebg(queue: alphaq, output, to: f)
                    }
                } else {
                    let code = types.map { type in
                        let convert = ptrconvert(type.ptrName)
                        return convert(type)
                    }.joined(separator: "\n\n")
                    outq.async(group: queues) { print(code) }
                }
            }

            background.async(group: queues) {
                let aliases = gir.aliases.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-aliases.swift"
                    let output = preamble + aliases
                    write(output, to: f)
                } else {
                    outq.async(group: queues) { print(aliases) } }
            }
            background.async(group: queues) {
                let callbacks = gir.callbacks.filter{!blacklist.contains($0.name)}.map(swiftCallbackAliasCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let output = preamble + callbacks
                    let f = "\(dir)/\(node)-callbacks.swift"
                    write(output, to: f)
                } else { outq.async(group: queues) { print(callbacks) } }
            }
            background.async(group: queues) {
                let constants = gir.constants.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-constants.swift"
                    let output = preamble + constants
                    write(output, to: f)
                } else {  outq.async(group: queues) { print(constants) } }
            }
            background.async(group: queues) {
                let enumerations = gir.enumerations.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-enumerations.swift"
                    let output = preamble + enumerations
                    write(output, to: f)
                } else { outq.async(group: queues) { print(enumerations) } }
            }
            background.async(group: queues) {
                let bitfields = gir.bitfields.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-bitfields.swift"
                    let output = preamble + bitfields
                    write(output, to: f)
                } else { outq.async(group: queues) { print(bitfields) } }
            }
            background.async(group: queues) {
                let convert = swiftUnionsConversion(gir.functions)
                let unions = gir.unions.filter {!blacklist.contains($0.name)}.map(convert).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-unions.swift"
                    let output = preamble + unions
                    write(output, to: f)
                } else { outq.async(group: queues) { print(unions) } }
            }
            background.async(group: queues) {
                let convert = swiftCode(gir.functions)
                let types = gir.interfaces.filter {!blacklist.contains($0.name)}
                write(types, using: convert)
            }
            background.async(group: queues) {
                let convert = swiftCode(gir.functions)
                var types = gir.records.filter {!blacklist.contains($0.name)}
                // If `generate all` option was not passed, the driver will not generate records wich are deemed as private.
                // Currently only Private records are ommited. Private record is a record, which has suffic Record and, class with it's name without work "Private" exists and contains only private references to this type or none at all. 
                // Since not all private attributes of classes are marked as private in .gir, only those records with non-private attributed references will be generated.
                if !generateAll {
                    let classes: [String: GIR.Class] = Dictionary(gir.classes.map { ($0.name, $0) }) { lhs, _ in lhs}
                    types.removeAll { record in 
                            record.name.hasSuffix("Private") &&
                            record.name.stringByRemoving(suffix: "Private")
                            .flatMap { classes[$0] }
                            .flatMap { $0.fields.allSatisfy { field in field.typeRef.type.name != record.name || field.isPrivate } } == true
                    }
                }
                write(types, using: convert)
            }
            background.async(group: queues) {
                let convert = swiftCode(gir.functions)
                let types = gir.classes.filter{!blacklist.contains($0.name)}
                write(types, using: convert)
            }
            background.async(group: queues) {
                let functions = gir.functions.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let output = preamble + functions
                    let f = "\(dir)/\(node)-functions.swift"
                    write(output, to: f)
                } else { outq.async(group: queues) { print(functions) } }
            }
            queues.wait()
            if verbose {
                print("** Verbatim: \(GIR.verbatimConstants.count)\n\(GIR.verbatimConstants.joined(separator: "\n"))\n", to: &Streams.stdErr)
                print("** Blacklisted: \(blacklist.count)\n\(blacklist.joined(separator: "\n\n"))\n", to: &Streams.stdErr)
            }
        }
    }
}
