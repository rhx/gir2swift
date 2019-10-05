//
//  getopt.swift
//  gir2swift
//
//  Created by Rene Hexel on 22/03/2016.
//  Copyright © 2016, 2019 Rene Hexel. All rights reserved.
//
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

///
/// Wrapper for POSIX `getopt()` to return a Swift tuple.
/// Returns `nil` if the `getopt()` returned -1,
/// otherwise returns a tuple of the option character
/// with an optional argument
///
public func get_opt(_ options: String) -> (Character, String?)? {
    let ch = getopt(CommandLine.argc, CommandLine.unsafeArgv, options)
    guard ch != -1 else { return nil }
    guard let u = UnicodeScalar(UInt32(ch)) else { return nil }
    let option = Character(u)
    let argument: String? = optarg != nil ? String(cString: optarg) : nil
    return (option, argument)
}
