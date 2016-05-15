//
//  mmap.swift
//  posix
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
/// memory map the given file with the given protection and flags,
/// then call the `process` function with the memory address of the
/// mapped file
///
func with_mmap(_ file: String, protection: Int32 = PROT_READ, flags: Int32 = MAP_PRIVATE, process: (UnsafeMutablePointer<Void>, Int) -> Void) {
    let fn = open(file, O_RDONLY)
    guard fn >= 0 else {
        perror("Cannot open '\(file)'")
        return
    }
    defer { close(fn) }
    guard let len = file_len(fn) else {
        perror("Cannot get length of '\(file)'")
        return
    }
    guard let mem = mmap(nil, len, protection, flags, fn, 0) where mem != UnsafeMutablePointer(bitPattern: -1) else {
        perror("Cannot mmap \(len) bytes for '\(file)'")
        return
    }
    defer { munmap(mem, len) }
    process(mem, len)
}

///
/// memory map the given file to an unsafe buffer pointer
/// then call the `process` function with the memory address of the
/// mapped file
///
func with_mmap<Element>(_ file: String, protection p: Int32 = PROT_READ, flags f: Int32 = MAP_PRIVATE, process: (UnsafeBufferPointer<Element>) -> Void) {
    with_mmap(file, protection: p, flags: f) { (mem: UnsafeMutablePointer<Void>, len: Int) -> Void in
        process(UnsafeBufferPointer<Element>(start: UnsafePointer<Element>(mem), count: len))
    }
}
