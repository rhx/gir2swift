//
//  String+ContentsOfFile.swift
//  Gtk3Swift
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
    var contents: String? { return String.fromContentsOfFile(self) }

    static func fromContentsOfFile(file: String) -> String? {
        let fn = open(file, O_RDONLY)
        guard fn >= 0 else {
            perror("Cannot open '\(file)'")
            return nil
        }
        defer { close(fn) }
        guard let len = file_len(fn) else {
            perror("Cannot get length of '\(file)'")
            return nil
        }
        let mem = malloc(len+1)
        guard mem != nil else {
            perror("malloc")
            return nil
        }
        defer { free(mem) }
        guard read(fn, mem, len) == len else {
            perror("Error reading '\(file)'")
            return nil
        }
        let cString = UnsafeMutablePointer<CChar>(mem)
        cString[len] = 0
        let (s, _) = String.fromCStringRepairingIllFormedUTF8(cString)
        return s
    }
}


