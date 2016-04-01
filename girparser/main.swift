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
    fputs("Usage: \(Process.arguments[0]) [-v] [file.gir ...]\n", stderr)
    exit(EXIT_FAILURE)
}

//
// get options
//
var verbose = false
while let (opt, param) = get_opt("v") {
    switch opt {
        case "v":
            verbose = true
        default:
            usage()
    }
}

func process_gir(file: String) {
    with_mmap(file) { (content: UnsafeBufferPointer<CChar>) in
        //write(STDOUT_FILENO, content.baseAddress, content.count)
        //        guard let xml = XMLDocument(fromFile: file) else {
        guard let gir = GIR(buffer: content) else {
            perror("Cannot parse GIR file '\(file)'")
            return
        }
        if gir.prefix.isEmpty {
            fputs("Warning: no namespace in GIR file '\(file)'\n", stderr)
        }
        print(gir.aliases.map(swiftCode).joinWithSeparator("\n\n"))
        print(gir.constants.map(swiftCode).joinWithSeparator("\n\n"))
//        gir.nameSpace = path.first!.
//        for element in xml {
//            print(element.debugDescription)
//        }
//        guard let path = gir.xml.xpath("//gir:record", namespaces: gir.namespaces, defaultPrefix: "gir") else {
//            fputs("Cannot create xpath\n", stderr)
//            return
//        }
//       print("\nXPath:")
//        for record in path {
//            print(record.debugDescription)
//        }
//        let swift = gir.dumpSwift()
//        print(swift)
//        //let records = xml //.filter { $0.name == "record" }
//        for record in gir.xml.filter({ $0.name == "namespace" }) {
//            print("\(record.name):")
//            for attribute in record.attributes {
//                print("    ", terminator: "")
//                if let value = gir.xml.valueFor(attribute) {
//                    print(attribute.name, "\"\(value)\"" , separator: "=")
//                } else {
//                    print(attribute.name)
//                }
//            }
//        }
    }
}

for file in Process.arguments[Int(optind)..<Process.arguments.count] {
    process_gir(file)
}
