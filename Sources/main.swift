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

/// verbose output
var verbose = false

@noreturn func usage() {
    fputs("Usage: \(Process.arguments[0]) [-v]{-p file.gir}[file.gir ...]\n", stderr)
    exit(EXIT_FAILURE)
}

/// load a GIR file, then invoke the processing closure
func load_gir(_ file: String, process: (GIR) -> Void) {
    with_mmap(file) { (content: UnsafeBufferPointer<CChar>) in
        guard let gir = GIR(buffer: content) else {
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
    load_gir(file) { _ in }
}


/// process a GIR file
func process_gir(file: String) {
    load_gir(file) { gir in
        processSpecialCases(gir, forFile: file)
        let blacklist = GIR.Blacklist
        print(gir.boilerPlate)
        print(gir.preamble)
        print(gir.aliases.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n"))
        print(gir.constants.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n"))
        print(gir.enumerations.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n"))
        print(gir.bitfields.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n"))
        print(gir.records.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n"))
        print(gir.classes.filter{!blacklist.contains($0.name)}.map(swiftCode).joined(separator: "\n\n"))
        if verbose {
            fputs("** Verbatim: \(GIR.VerbatimConstants.count)\n\(GIR.VerbatimConstants.joined(separator: "\n"))\n\n", stderr)
            fputs("** Blacklisted: \(blacklist.count)\n\(blacklist.joined(separator: "\n\n"))\n\n", stderr)
        }
    }
}


/// process blacklist and verbatim constants information
func processSpecialCases(_
    gir: GIR, forFile file: String) {
    let base = file.baseName
    let node = base.stringByRemoving(suffix: ".gir") ?? base
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

for argument in Process.arguments[Int(optind)..<Process.arguments.count] {
    process_gir(file: argument)
}
