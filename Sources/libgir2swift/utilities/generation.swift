#if os(Linux)
    import Glibc
#else
    import Darwin
#endif
import Foundation
import Dispatch
import libgir2swift

extension Gir2Swift {

    /// load a GIR file, then invoke the processing closure
    func load_gir(_ file: String, quiet q: Bool = false, process: (GIR) -> Void =  { _ in }) {
        with_mmap(file) { (content: UnsafeBufferPointer<CChar>) in
            guard let gir = GIR(buffer: content, quiet: q) else {
                perror("Cannot parse GIR file '\(file)'")
                return
            }
            if gir.prefix.isEmpty {
                fputs("Warning: no namespace in GIR file '\(file)'\n", stderr)
            }
            process(gir);
        }
    }

    /// pre-load a GIR without processing, but adding to known types / records
    func preload_gir(file: String) {
        load_gir(file, quiet: true)
    }

    /// process a GIR file
    func process_gir(file: String, boilerPlate modulePrefix: String, to outputDirectory: String? = nil, split singleFilePerClass: Bool = false, generateAll: Bool = false) {
        let base = file.baseName
        let node = base.stringByRemoving(suffix: ".gir") ?? base
        let wlfile = node + ".whitelist"
        if let whitelist = String(contentsOfFile: wlfile, quiet: true).flatMap({ Set($0.lines) }) {
            for name in whitelist {
                GIR.knownDataTypes.removeValue(forKey: name)
                GIR.knownRecords.removeValue(forKey: name)
                GIR.KnownFunctions.removeValue(forKey: name)
            }
        }
        let escfile = node + ".callbackSuffixes"
        GIR.callbackSuffixes = String(contentsOfFile: escfile, quiet: true)?.lines ?? [
            "Notify", "Func", "Marshaller", "Callback"
        ]
        let nsfile = node + ".namespaceReplacements"
        if let ns = String(contentsOfFile: nsfile, quiet: true).flatMap({Set($0.lines)}) {
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
            processSpecialCases(gir, forFile: node)
            let blacklist = GIR.blacklist
            let boilerplate = gir.boilerPlate
            let prefix = gir.preamble
            let modulePrefix = modulePrefix + boilerplate
            let queues = DispatchGroup()
            let background = DispatchQueue.global()
            let outq = DispatchQueue(label: "com.github.rhx.gir2swift.outputqueue")
            if outputDirectory == nil { print(modulePrefix + prefix) }

            func write(_ string: String, to fileName: String) {
                do {
                    try string.writeTo(file: fileName)
                } catch {
                    outq.async(group: queues) { fputs("\(error)\n", stderr) }
                }
            }
            func writebg(_ string: String, to fileName: String) {
                background.async(group: queues) { write(string, to: fileName) }
            }
            func write<T: GIR.Record>(_ types: [T], using ptrconvert: (String) -> (GIR.Record) -> String) {
                if let dir = outputDirectory {
                    writebg(modulePrefix, to: "\(dir)/\(node).swift")
                    var output = prefix
                    var first: Character? = nil
                    var firstName = ""
                    var name = ""
                    for type in types {
                        let convert = ptrconvert(type.ptrName)
                        let code = convert(type)
                        
                        output += code + "\n\n"
                        name = type.className
                        guard let firstChar = name.first else { continue }
                        guard singleFilePerClass || ( first != nil && first != firstChar ) else {
                            if first == nil {
                                first = firstChar
                                firstName = name + "-"
                            }
                            continue
                        }
                        let f = "\(dir)/\(node)-\(firstName)\(name).swift"
                        writebg(output, to: f)
                        output = prefix
                        first = nil
                    }
                    if first != nil {
                        let f = "\(dir)/\(node)-\(firstName)\(name).swift"
                        writebg(output, to: f)
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
                    let output = prefix + aliases
                    write(output, to: f)
                } else {
                    outq.async(group: queues) { print(aliases) } }
            }
            background.async(group: queues) {
                let callbacks = gir.callbacks.filter{!blacklist.contains($0.name)}.map(swiftCallbackAliasCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let output = prefix + callbacks
                    let f = "\(dir)/\(node)-callbacks.swift"
                    write(output, to: f)
                } else { outq.async(group: queues) { print(callbacks) } }
            }
            background.async(group: queues) {
                let constants = gir.constants.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-constants.swift"
                    let output = prefix + constants
                    write(output, to: f)
                } else {  outq.async(group: queues) { print(constants) } }
            }
            background.async(group: queues) {
                let enumerations = gir.enumerations.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-enumerations.swift"
                    let output = prefix + enumerations
                    write(output, to: f)
                } else { outq.async(group: queues) { print(enumerations) } }
            }
            background.async(group: queues) {
                let bitfields = gir.bitfields.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-bitfields.swift"
                    let output = prefix + bitfields
                    write(output, to: f)
                } else { outq.async(group: queues) { print(bitfields) } }
            }
            background.async(group: queues) {
                let convert = swiftUnionsConversion(gir.functions)
                let unions = gir.unions.filter {!blacklist.contains($0.name)}.map(convert).joined(separator: "\n\n")
                if let dir = outputDirectory {
                    let f = "\(dir)/\(node)-unions.swift"
                    let output = prefix + unions
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
                    let output = prefix + functions
                    let f = "\(dir)/\(node)-functions.swift"
                    write(output, to: f)
                } else { outq.async(group: queues) { print(functions) } }
            }
            queues.wait()
            if verbose {
                fputs("** Verbatim: \(GIR.verbatimConstants.count)\n\(GIR.verbatimConstants.joined(separator: "\n"))\n\n", stderr)
                fputs("** Blacklisted: \(blacklist.count)\n\(blacklist.joined(separator: "\n\n"))\n\n", stderr)
            }
        }
    }

    /// process blacklist and verbatim constants information
    func processSpecialCases(_ gir: GIR, forFile node: String) {
        let preamble = node + ".preamble"
        gir.preamble = preamble.contents ?? ""
        let blacklist = node + ".blacklist"
        GIR.blacklist = blacklist.contents.flatMap { Set($0.lines) } ?? []
        let verbatimConstants = node + ".verbatim"
        GIR.verbatimConstants = verbatimConstants.contents.flatMap { Set($0.lines) } ?? []
        let overrideFile = node + ".override"
        GIR.overrides = overrideFile.contents.flatMap { Set($0.lines) } ?? []
    }

}
