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
        let group = DispatchGroup()
        let background = DispatchQueue.global()
        let main = DispatchQueue.main
        background.async(group: group) {
            let aliases = gir.aliases.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-aliases.swift"
                do { try aliases.writeTo(file: f) }
                catch { main.async { fputs("\(error)\n", stderr) } }
            } else { let output = prefix + aliases ; main.async { print(output) } }
        }
        background.async(group: group) {
            let callbacks = gir.callbacks.filter{!blacklist.contains($0.name)}.map(swiftCallbackAliasCode).joined(separator: "\n\n")
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-callbacks.swift"
                do { try callbacks.writeTo(file: f) }
                catch { main.async { fputs("\(error)\n", stderr) } }
            } else { let output = prefix + callbacks ; main.async { print(output) } }
        }
        background.async(group: group) {
            let constants = gir.constants.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-constants.swift"
                do { try constants.writeTo(file: f) }
                catch { main.async { fputs("\(error)\n", stderr) } }
            } else { let output = prefix + constants ; main.async { print(output) } }
        }
        background.async(group: group) {
            let enumerations = gir.enumerations.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-enumerations.swift"
                do { try enumerations.writeTo(file: f) }
                catch { main.async { fputs("\(error)\n", stderr) } }
            } else { let output = prefix + enumerations ; main.async { print(output) } }
        }
        background.async(group: group) {
            let bitfields = gir.bitfields.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-bitfields.swift"
                do { try bitfields.writeTo(file: f) }
                catch { main.async { fputs("\(error)\n", stderr) } }
            } else { let output = prefix + bitfields ; main.async { print(output) } }
        }
        background.async(group: group) {
            let interfaces = gir.interfaces.filter {!blacklist.contains($0.name)}.map(swiftCode(gir.functions)).joined(separator: "\n\n")
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-interfaces.swift"
                do { try interfaces.writeTo(file: f) }
                catch { main.async { fputs("\(error)\n", stderr) } }
            } else { let output = prefix + interfaces ; main.async { print(output) } }
        }
        background.async(group: group) {
            let records = gir.records.filter {!blacklist.contains($0.name)}.map(swiftCode(gir.functions))
            if let dir = outputDirectory {
                for record in records {
                    let f = "\(dir)/\(node)-\(record.swiftName).swift"
                    do { try record.writeTo(file: f) }
                    catch { main.async { fputs("\(error)\n", stderr) } }
                }
            } else { let output = prefix + records.joined(separator: "\n\n") ; main.async { print(output) } }
        }
        background.async(group: group) {
            let classes = gir.classes.filter{!blacklist.contains($0.name)}.map(swiftCode(gir.functions))
            if let dir = outputDirectory {
                for c in classes {
                    let f = "\(dir)/\(node)-\(c.swiftName).swift"
                    do { try c.writeTo(file: f) }
                    catch { main.async { fputs("\(error)\n", stderr) } }
                }
            } else { let output = prefix + classes.joined(separator: "\n\n") ; main.async { print(output) } }
        }
        background.async(group: group) {
            let functions = gir.functions.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n")
            if let dir = outputDirectory {
                let f = "\(dir)/\(node)-functions.swift"
                do { try functions.writeTo(file: f) }
                catch { main.async { fputs("\(error)\n", stderr) } }
            } else { let output = prefix + functions ; main.async { print(output) } }
        }
        group.wait()
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
while let (opt, param) = get_opt("p:v") {
    switch opt {
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
    process_gir(file: argument)
}
