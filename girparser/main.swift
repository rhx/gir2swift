//
//  main.swift
//  girparser
//
//  Created by Rene Hexel on 22/03/2016.
//  Copyright © 2016 Rene Hexel. All rights reserved.
//
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

@noreturn func usage() {
    fputs("Usage: \(Process.arguments[0]) [-v]{-p file.gir}[file.gir ...]\n", stderr)
    exit(EXIT_FAILURE)
}

/// load a GIR file, then invoke the processing closure
func load_gir(file: String, process: GIR -> Void) {
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
        print(gir.boilerPlate)
        print(gir.aliases.filter{!gir.blacklist.contains($0.name)}.map(swiftCode).joinWithSeparator("\n\n"))
        print(gir.constants.filter{!gir.blacklist.contains($0.name)}.map(swiftCode).joinWithSeparator("\n\n"))
        print(gir.enumerations.filter{!gir.blacklist.contains($0.name)}.map(swiftCode).joinWithSeparator("\n\n"))
        print(gir.bitfields.filter{!gir.blacklist.contains($0.name)}.map(swiftCode).joinWithSeparator("\n\n"))
        print(gir.records.filter{!gir.blacklist.contains($0.name)}.map(swiftCode).joinWithSeparator("\n\n"))
        print(gir.classes.filter{!gir.blacklist.contains($0.name)}.map(swiftCode).joinWithSeparator("\n\n"))
    }
}


/// process blacklist and verbatim constants information
func processSpecialCases(gir: GIR, forFile file: String) {
    let base = file.baseName
    let node = base.stringByRemoving(suffix: ".gir") ?? base
    let blacklist = node + ".blacklist"
    gir.blacklist = blacklist.contents?.lines.asSet ?? []
    let consts = node + ".verbatim"
    GIR.VerbatimConstants = consts.contents?.lines.asSet ?? []
}


//
// get options
//
var verbose = false
while let (opt, param) = get_opt("p:v") {
    switch opt {
        case "p":
            guard let file = param else { usage() }
            preload_gir(param!)
        case "v":
            verbose = true
        default:
            usage()
    }
}

for file in Process.arguments[Int(optind)..<Process.arguments.count] {
    process_gir(file)
}
