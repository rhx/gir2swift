//
//  FileLen.swift
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

///
/// Return the length of the given file or `nil` if an error occurred
///
func file_len(_ fn: CInt) -> Int? {
    let offs = lseek(fn, 0, SEEK_CUR)
    guard offs >= 0 else { return nil }
    defer { lseek(fn, offs, SEEK_SET) }
    let len = lseek(fn, 0, SEEK_END)
    guard len >= 0 else { return nil }
    return Int(len)
}
