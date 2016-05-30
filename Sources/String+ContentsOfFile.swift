//
//  String+ContentsOfFile.swift
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


extension String {
    var contents: String? { return String(contentsOfFile: self) }

    init?(contentsOfFile file: String, quiet: Bool = false) {
        let fn = open(file, O_RDONLY)
        guard fn >= 0 else {
            if !quiet { perror("Cannot open '\(file)'") }
            return nil
        }
        defer { close(fn) }
        guard let len = file_len(fn) else {
            perror("Cannot get length of '\(file)'")
            return nil
        }
        guard let mem = malloc(len+1) else {
            perror("malloc")
            return nil
        }
        defer { free(mem) }
        guard read(fn, mem, len) == len else {
            perror("Error reading '\(file)'")
            return nil
        }
        let cs = UnsafeMutablePointer<CChar>(mem)
        cs[len] = 0
        self = String(cString: UnsafePointer(cs))
    }
}
