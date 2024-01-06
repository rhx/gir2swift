//
//  generation.swift
//  gir2swift
//
//  Created by Rene Hexel on 20/5/2021.
//  Copyright © 2016, 2017, 2018, 2019, 2020, 2021, 2022 Rene Hexel. All rights reserved.
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

/// Process exclusions and verbatim constants information.
///
/// This function will parse the content of various special files
/// that modify the behaviour of `gir2swift`.
///
/// - Parameters:
///   - gir: The in-memory object representing the `.gir` file
///   - targetDirectoryURL: URL representing the target source directory containing the module configuration files
///   - node: File name node of the `.gir` file without extension
private func processSpecialCases(_ gir: GIR, for targetDirectoryURL: URL, node: String) {
    let prURL = targetDirectoryURL.appendingPathComponent(node + ".preamble")
    gir.preamble = (try? String(contentsOf: prURL)) ?? ""
    let exURL = targetDirectoryURL.appendingPathComponent(node + ".exclude")
    let blURL = targetDirectoryURL.appendingPathComponent(node + ".blacklist")
    GIR.excludeList = ((try? String(contentsOf: exURL)) ?? (try? String(contentsOf: blURL))).flatMap { Set($0.nonEmptyComponents(separatedBy: "\n")) } ?? []
    let vbURL = targetDirectoryURL.appendingPathComponent(node + ".verbatim")
    GIR.verbatimConstants = (try? String(contentsOf: vbURL)).flatMap { Set($0.nonEmptyComponents(separatedBy: "\n")) } ?? []
    let ovURL = targetDirectoryURL.appendingPathComponent(node + ".override")
    GIR.overrides = (try? String(contentsOf: ovURL)).flatMap { Set($0.nonEmptyComponents(separatedBy: "\n")) } ?? []
    let tcURL = targetDirectoryURL.appendingPathComponent(node + ".typedCollections")
    GIR.typedCollections = (try? String(contentsOf: tcURL)).flatMap { Set($0.nonEmptyComponents(separatedBy: "\n")) } ?? GIR.typedCollections
}

extension Gir2Swift {

    /// pre-load a GIR without processing, but adding to known types / records
    func preload_gir(file: String) {
        load_gir(file, quiet: true)
    }

    /// process a GIR file
    /// - Parameters:
    ///   - file: The `.gir` file to proces
    ///   - targetDirectoryURL: URL representing the target source directory containing the module configuration files
    ///   - boilerPlate: A string containing the boilerplate to use for the generated module file, `<node>.module` file if empty
    ///   - outputDirectory: The directory to output generated files in, `stdout` if `nil`
    ///   - docCHostingBasePath: The base URL for the documentation comments.
    ///   - singleFilePerClass: Flag indicating whether a separate output file should be created per class
    ///   - generateAll: Flag indicating whether private members should be emitted
    ///   - useAlphaNames: Flag indicating whether a fixed number of output files should be generated
    ///   - postProcess: Array of additional file names to include in post-processing
    func process_gir(file: String, for targetDirectoryURL: URL, boilerPlate: String, to outputDirectory: String? = nil, docCHostingBasePath: String, split singleFilePerClass: Bool = false, generateAll: Bool = false, useAlphaNames: Bool = false, postProcess additionalFilesToPostProcess: [String]) {
        let node = file.components(separatedBy: "/").last?.stringByRemoving(suffix: ".gir") ?? file
        let modulePrefix: String
        if boilerPlate.isEmpty {
            let bpURL = targetDirectoryURL.appendingPathComponent(node + ".module")
            modulePrefix = (try? String(contentsOf: bpURL)) ?? boilerPlate
        } else {
            modulePrefix = boilerPlate
        }
        GIR.docCHostingBasePath = docCHostingBasePath
        let pkgConfigArg = pkgConfigName ?? node.lowercased()
        let inURL = targetDirectoryURL.appendingPathComponent(node + ".include")
        let wlURL = targetDirectoryURL.appendingPathComponent(node + ".whitelist")
        if let inclusionList = ((try? String(contentsOf: inURL)) ?? (try? String(contentsOf: wlURL))).flatMap({ Set($0.nonEmptyComponents(separatedBy: "\n")) }) {
            for name in inclusionList {
                GIR.knownDataTypes.removeValue(forKey: name)
                GIR.knownRecords.removeValue(forKey: name)
                GIR.KnownFunctions.removeValue(forKey: name)
            }
        }
        let escURL = targetDirectoryURL.appendingPathComponent(node + ".callbackSuffixes")
        GIR.callbackSuffixes = (try? String(contentsOf: escURL))?.nonEmptyComponents(separatedBy: "\n") ?? [
            "Notify", "Func", "Marshaller", "Callback"
        ]
        let nsURL = targetDirectoryURL.appendingPathComponent(node + ".namespaceReplacements")
        if let ns = (try? String(contentsOf: nsURL)).flatMap({Set($0.nonEmptyComponents(separatedBy: "\n"))}) {
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
        var outputFiles = Set(additionalFilesToPostProcess)
        var outputString = ""

        load_gir(file) { gir in
            processSpecialCases(gir, for: targetDirectoryURL, node: node)
            let exclusions = GIR.excludeList
            let boilerplate = gir.boilerPlate
            let preamble = gir.preamble
            let modulePrefix = modulePrefix + boilerplate
            let queues = DispatchGroup()
            let background = DispatchQueue.global()
            let atChar = Character("@").utf8.first!
            let alphaQueues = useAlphaNames ? (0...26).map { i in
                DispatchQueue(label: "com.github.rhx.gir2swift.alphaqueue.\(Character(UnicodeScalar(atChar + UInt8(i))))")
            } : []
            let outq = DispatchQueue(label: "com.github.rhx.gir2swift.outputqueue")
            if outputDirectory == nil { outputString += modulePrefix + preamble }

            func write(_ string: String, to fileName: String, preamble: String = preamble, append doAppend: Bool = false) {
                do {
                    if doAppend && fileManager.fileExists(atPath: fileName) {
                        let oldContent = try String(contentsOfFile: fileName, encoding: .utf8)
                        let newContent = oldContent + string
                        try newContent.write(toFile: fileName, atomically: true, encoding: .utf8)
                    } else {
                        let newContent = preamble + string
                        try newContent.write(toFile: fileName, atomically: true, encoding: .utf8)
                    }
                    outq.async(group: queues) { outputFiles.insert(fileName) }
                } catch {
                    outq.async(group: queues) { print("\(error)", to: &Streams.stdErr) }
                }
            }
            func writebg(queue: DispatchQueue = background, _ string: String, to fileName: String, append doAppend: Bool = false) {
                queue.async(group: queues) { write(string, to: fileName, append: doAppend) }
            }
            func write<T: GIR.Record>(_ types: [T], using ptrconvert: (String) -> (GIR.Record) -> String) {
                if let dir = outputDirectory {
                    var output = ""
                    var first: Character? = nil
                    var firstName = ""
                    var name = ""
                    var alphaq = background
                    for type in types {
                        let convert = ptrconvert(type.ptrName)
                        let code = convert(type)
                        
                        output += code + "\n\n"
                        name = type.className
                        guard let firstChar = name.first else { continue }
                        let f: String
                        if useAlphaNames {
                            name = firstChar.isASCII && firstChar.isLetter ? type.className.upperInitial : "@"
                            first = firstChar
                            firstName = name
                            let i = Int((name.utf8.first ?? atChar) - atChar)
                            alphaq = alphaQueues[i]
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
                        writebg(queue: alphaq, output, to: f, append: useAlphaNames)
                        output = ""
                        first = nil
                    }
                    if first != nil {
                        let f: String
                        if useAlphaNames {
                            let i = Int((name.utf8.first ?? atChar) - atChar)
                            alphaq = alphaQueues[i]
                            f = "\(dir)/\(node)-\(firstName).swift"
                        } else {
                            f = "\(dir)/\(node)-\(firstName)\(name).swift"
                        }
                        writebg(queue: alphaq, output, to: f, append: useAlphaNames)
                    }
                } else {
                    let code = types.map { type in
                        let convert = ptrconvert(type.ptrName)
                        return convert(type)
                    }.joined(separator: "\n\n")
                    outq.async(group: queues) { outputString += code }
                }
            }

            if let dir = outputDirectory {
                writebg(modulePrefix, to: "\(dir)/\(node).swift")
                DispatchQueue.concurrentPerform(iterations: 27) { i in
                    let ascii = atChar + UInt8(i)
                    let f = "\(dir)/\(node)-\(Character(UnicodeScalar(ascii))).swift"
                    try? fileManager.removeItem(atPath: f)
                    if useAlphaNames {
                        try? preamble.write(toFile: f, atomically: true, encoding: .utf8)
                        outq.async(group: queues) { outputFiles.insert(f) }
                    }
                }
            }

            background.async(group: queues) {
                let aliases = gir.aliases.filter{!exclusions.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-aliases.swift"
                    write(aliases, to: f)
                } else {
                    outq.async(group: queues) { outputString += aliases } }
            }
            background.async(group: queues) {
                let callbacks = gir.callbacks.filter{!exclusions.contains($0.name)}.map(swiftCallbackAliasCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-callbacks.swift"
                    write(callbacks, to: f)
                } else { outq.async(group: queues) { outputString += callbacks } }
            }
            background.async(group: queues) {
                let constants = gir.constants.filter{!exclusions.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-constants.swift"
                    write(constants, to: f)
                } else {  outq.async(group: queues) { outputString += constants } }
            }
            background.async(group: queues) {
                let enumerations = gir.enumerations.filter{!exclusions.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-enumerations.swift"
                    write(enumerations, to: f)
                } else { outq.async(group: queues) { outputString += enumerations } }
            }
            background.async(group: queues) {
                let bitfields = gir.bitfields.filter{!exclusions.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-bitfields.swift"
                    write(bitfields, to: f)
                } else { outq.async(group: queues) { outputString += bitfields } }
            }
            background.async(group: queues) {
                let convert = swiftUnionsConversion(gir.functions)
                let unions = gir.unions.filter {!exclusions.contains($0.name)}.map(convert).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-unions.swift"
                    write(unions, to: f)
                } else { outq.async(group: queues) { outputString += unions } }
            }
            background.async(group: queues) {
                let convert = swiftCode(gir.functions)
                let types = gir.interfaces.filter {!exclusions.contains($0.name)}
                write(types, using: convert)
            }
            background.async(group: queues) {
                let convert = swiftCode(gir.functions)
                let classes = generateAll ? [:] : Dictionary(gir.classes.map { ($0.name, $0) }) { lhs, _ in lhs}
                let records = gir.records.filter { r in
                    !exclusions.contains(r.name) 
                    &&
                    (
                        generateAll 
                        || !r.name.hasSuffix("Private") 
                        || r.name.stringByRemoving(suffix: "Private").flatMap { classes[$0] }.flatMap { $0.fields.allSatisfy { $0.isPrivate || $0.typeRef.type.name != r.name }} != true
                    )
                }
                write(records, using: convert)
            }
            background.async(group: queues) {
                let convert = swiftCode(gir.functions)
                let types = gir.classes.filter{!exclusions.contains($0.name)}
                write(types, using: convert)
            }
            background.async(group: queues) {
                let functions = gir.functions.filter{!exclusions.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-functions.swift"
                    write(functions, to: f)
                } else { outq.async(group: queues) { outputString += functions } }
            }
            if !(namespace.isEmpty && extensionNamespace.isEmpty) {
                let namespaces = namespace + extensionNamespace
                let extensions = Set(extensionNamespace)
                background.async(group: queues) {
                    let privatePrefix = "_" + gir.prefix + "_"
                    let prefixedAliasSwiftCode = typeAliasSwiftCode(prefixedWith: privatePrefix)
                    let privateRecords = gir.records.filter{!exclusions.contains($0.name)}.map(prefixedAliasSwiftCode).joined(separator: "\n")
                    let privateAliases = gir.aliases.filter{!exclusions.contains($0.name)}.map(prefixedAliasSwiftCode).joined(separator: "\n")
                    let privateEnumerations = gir.enumerations.filter{!exclusions.contains($0.name)}.map(prefixedAliasSwiftCode).joined(separator: "\n")
                    let privateBitfields = gir.bitfields.filter{!exclusions.contains($0.name)}.map(prefixedAliasSwiftCode).joined(separator: "\n")
                    let privateUnions = gir.unions.filter {!exclusions.contains($0.name)}.map(prefixedAliasSwiftCode).joined(separator: "\n")
                    let code = [privateRecords, privateAliases, privateEnumerations, privateBitfields, privateUnions].joined(separator: "\n\n") + "\n"
                    let outputFile = outputDirectory.map { "\($0)/\(node)-namespaces.swift" }
                    if let f = outputFile {
                        write(code, to: f, preamble: preamble)
                    } else {
                        outq.async(group: queues) { outputString += code }
                    }
                    let indent = "    "
                    let constSwiftCode = constantSwiftCode(indentedBy: indent, scopePrefix: "static")
                    let datatypeSwiftCode = namespacedAliasSwiftCode(prefixedWith: privatePrefix, indentation: indent)
                    let constants = gir.constants.filter{!exclusions.contains($0.name)}.map(constSwiftCode).joined(separator: "\n")
                    let aliases = gir.aliases.filter{!exclusions.contains($0.name)}.map(datatypeSwiftCode).joined(separator: "\n")
                    let enumerations = gir.enumerations.filter{!exclusions.contains($0.name)}.map(datatypeSwiftCode).joined(separator: "\n")
                    let bitfields = gir.bitfields.filter{!exclusions.contains($0.name)}.map(datatypeSwiftCode).joined(separator: "\n")
                    let unions = gir.unions.filter {!exclusions.contains($0.name)}.map(datatypeSwiftCode).joined(separator: "\n")
                    let classes = generateAll ? [:] : Dictionary(gir.classes.map { ($0.name, $0) }) { lhs, _ in lhs}
                    let records = gir.records.filter { r in
                        !exclusions.contains(r.name) &&
                        (generateAll || !r.name.hasSuffix("Private") ||
                         r.name.stringByRemoving(suffix: "Private").flatMap { classes[$0] }.flatMap {
                            $0.fields.allSatisfy { $0.isPrivate || $0.typeRef.type.name != r.name }
                        } != true
                        )
                    }.map(datatypeSwiftCode).joined(separator: "\n\n")
                    namespaces.forEach { namespace in
                        let namespaceDeclaration: String
                        if extensions.contains(namespace) {
                            namespaceDeclaration = "extension " + namespace + " {\n"
                        } else if let record = GIR.knownRecords[namespace] {
                            namespaceDeclaration = "extension " + record.className + " {\n"
                        } else {
                            namespaceDeclaration = "public enum " + namespace + " {\n"
                        }
                        let code = namespaceDeclaration + [constants, records, aliases, enumerations, bitfields, unions].joined(separator: "\n\n") + "\n}\n\n"
                        if let f = outputFile {
                            write(code, to: f, append: true)
                        } else {  outq.async(group: queues) { outputString += code } }
                    }
                }
            }
            queues.wait()
            libgir2swift.postProcess(node, for: targetDirectoryURL, pkgConfigName: pkgConfigArg, outputString: outputString, outputDirectory: outputDirectory, outputFiles: outputFiles)
            if verbose {
                let pf = outputString.isEmpty ? "** " : "// "
                let nl = outputString.isEmpty ? "\n"  : "\n// "
                print("\(pf)Verbatim: \(GIR.verbatimConstants.count)\(nl)\(GIR.verbatimConstants.joined(separator: nl))\n", to: &Streams.stdErr)
                print("\(pf)Blacklisted: \(exclusions.count)\(nl)\(exclusions.joined(separator: "\n" + nl))\n", to: &Streams.stdErr)
            }
        }
    }

    /// create opaque pointer declarations
    func process_gir_to_opaque_decls(file: String, in targetDirectoryURL: URL, generateAll: Bool = false) {
        let node = file.components(separatedBy: "/").last?.stringByRemoving(suffix: ".gir") ?? file
        let inURL = targetDirectoryURL.appendingPathComponent(node + ".include")
        let wlURL = targetDirectoryURL.appendingPathComponent(node + ".whitelist")
        if let inclusionList = ((try? String(contentsOf: inURL)) ?? (try? String(contentsOf: wlURL))).flatMap({ Set($0.nonEmptyComponents(separatedBy: "\n")) }) {
            for name in inclusionList {
                GIR.knownDataTypes.removeValue(forKey: name)
                GIR.knownRecords.removeValue(forKey: name)
                GIR.KnownFunctions.removeValue(forKey: name)
            }
        }
        let nsURL = targetDirectoryURL.appendingPathComponent(node + ".namespaceReplacements")
        if let ns = (try? String(contentsOf: nsURL)).flatMap({Set($0.nonEmptyComponents(separatedBy: "\n"))}) {
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

        load_gir(file) { gir in
            processSpecialCases(gir, for: targetDirectoryURL, node: node)
            let blacklist = GIR.excludeList
            let classes = generateAll ? [:] : Dictionary(gir.classes.map { ($0.name, $0) }) { lhs, _ in lhs}
            let records = gir.records.filter { r in
                !blacklist.contains(r.name) 
                &&
                (
                    generateAll 
                    || !r.name.hasSuffix("Private") 
                    || r.name.stringByRemoving(suffix: "Private").flatMap { classes[$0] }.flatMap { $0.fields.allSatisfy { $0.isPrivate || $0.typeRef.type.name != r.name }} != true
                )
            }

            for recordCName in records.compactMap(\.correspondingCType) {
                print("struct " + recordCName + " {};")
            }
        }
    }
}
