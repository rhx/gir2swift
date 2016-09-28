//
//  main.swift
//  gir2swift
//
//  Created by Rene Hexel on 22/03/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif
import Dispatch

/// verbose output
var verbose = false

func usage() -> Never  {
    fputs("Usage: \(CommandLine.arguments[0]) [-v]{-p file.gir}[file.gir ...]\n", stderr)
    exit(EXIT_FAILURE)
}

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
func process_gir(file: String, to outputDirectory: String? = nil) {
    let base = file.baseName
    let node = base.stringByRemoving(suffix: ".gir") ?? base
    let wlfile = node + ".whitelist"
    if let whitelist = String(contentsOfFile: wlfile, quiet: true)?.lines.asSet {
        for name in whitelist {
            GIR.KnownTypes.removeValue(forKey: name)
            GIR.KnownRecords.removeValue(forKey: name)
            GIR.KnownFunctions.removeValue(forKey: name)
        }
    }

    load_gir(file) { gir in
        processSpecialCases(gir, forFile: node)
        let blacklist = GIR.Blacklist
        let boilerplate = gir.boilerPlate
        let preamble = gir.preamble
        let prefix = boilerplate + preamble
        let queues = DispatchGroup()
        let background = DispatchQueue.global()
        let outq = DispatchQueue(label: "com.github.rhx.gir2swift.outputqueue")
        background.async(group: queues) {
            let aliases = gir.aliases.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
            let output = prefix + aliases
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-aliases.swift"
                do { try output.writeTo(file: f) }
                catch { outq.async(group: queues) { fputs("\(error)\n", stderr) } }
            } else { outq.async(group: queues) { print(output) } }
        }
        background.async(group: queues) {
            let callbacks = gir.callbacks.filter{!blacklist.contains($0.name)}.map(swiftCallbackAliasCode).joined(separator: "\n\n")
            let output = prefix + callbacks
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-callbacks.swift"
                do { try output.writeTo(file: f) }
                catch { outq.async(group: queues) { fputs("\(error)\n", stderr) } }
            } else { outq.async(group: queues) { print(output) } }
        }
        background.async(group: queues) {
            let constants = gir.constants.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
            let output = prefix + constants
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-constants.swift"
                do { try output.writeTo(file: f) }
                catch { outq.async(group: queues) { fputs("\(error)\n", stderr) } }
            } else {  outq.async(group: queues) { print(output) } }
        }
        background.async(group: queues) {
            let enumerations = gir.enumerations.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
            let output = prefix + enumerations
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-enumerations.swift"
                do { try output.writeTo(file: f) }
                catch { outq.async(group: queues) { fputs("\(error)\n", stderr) } }
            } else { outq.async(group: queues) { print(output) } }
        }
        background.async(group: queues) {
            let bitfields = gir.bitfields.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
            let output = prefix + bitfields
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-bitfields.swift"
                do { try output.writeTo(file: f) }
                catch { outq.async(group: queues) { fputs("\(error)\n", stderr) } }
            } else { outq.async(group: queues) { print(output) } }
        }
        background.async(group: queues) {
            let interfaces = gir.interfaces.filter {!blacklist.contains($0.name)}.map(swiftCode(gir.functions)).joined(separator: "\n\n")
            let output = prefix + interfaces
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-interfaces.swift"
                do { try output.writeTo(file: f) }
                catch { outq.async(group: queues) { fputs("\(error)\n", stderr) } }
            } else { outq.async(group: queues) { print(output) } }
        }
        background.async(group: queues) {
            let records = gir.records.filter {!blacklist.contains($0.name)}.map(swiftCode(gir.functions))
            if let dir = outputDirectory {
                for record in records {
                    let output = prefix + record
                    let f = "\(dir)/\(node)-\(record.swiftName).swift"
                    do { try output.writeTo(file: f) }
                    catch { outq.async(group: queues) { fputs("\(error)\n", stderr) } }
                }
            } else {
                let output = prefix + records.joined(separator: "\n\n")
                outq.async(group: queues) { print(output) }
            }
        }
        background.async(group: queues) {
            let classes = gir.classes.filter{!blacklist.contains($0.name)}.map(swiftCode(gir.functions))
            if let dir = outputDirectory {
                for c in classes {
                    let output = prefix + c
                    let f = "\(dir)/\(node)-\(c.swiftName).swift"
                    do { try output.writeTo(file: f) }
                    catch { outq.async(group: queues) { fputs("\(error)\n", stderr) } }
                }
            } else {
                let output = prefix + classes.joined(separator: "\n\n")
                outq.async(group: queues) { print(output) }
            }
        }
        background.async(group: queues) {
            let functions = gir.functions.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
            let output = prefix + functions
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-functions.swift"
                do { try output.writeTo(file: f) }
                catch { outq.async(group: queues) { fputs("\(error)\n", stderr) } }
            } else { outq.async(group: queues) { print(output) } }
        }
        queues.wait()
        if verbose {
            fputs("** Verbatim: \(GIR.VerbatimConstants.count)\n\(GIR.VerbatimConstants.joined(separator: "\n"))\n\n", stderr)
            fputs("** Blacklisted: \(blacklist.count)\n\(blacklist.joined(separator: "\n\n"))\n\n", stderr)
        }
    }
}


/// process blacklist and verbatim constants information
func processSpecialCases(_ gir: GIR, forFile node: String) {
    let preamble = node + ".preamble"
    gir.preamble = preamble.contents ?? ""
    let blacklist = node + ".blacklist"
    GIR.Blacklist = blacklist.contents?.lines.asSet ?? []
    let verbatimConstants = node + ".verbatim"
    GIR.VerbatimConstants = verbatimConstants.contents?.lines.asSet ?? []
}


//
// get options
//
var outputDirectory: String?
while let (opt, param) = get_opt("o:p:v") {
    switch opt {
        case "o":
            outputDirectory = param
            guard outputDirectory != nil else { usage() }
        case "p":
            guard let file = param else { usage() }
            preload_gir(file: param!)
        case "v":
            verbose = true
        default:
            usage()
    }
}

for argument in CommandLine.arguments[Int(optind)..<CommandLine.arguments.count] {
    process_gir(file: argument, to: outputDirectory)
}
