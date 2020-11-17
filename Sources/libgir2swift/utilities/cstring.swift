//
//  cstring.swift
//  posix
//
//  Created by Rene Hexel on 2/08/2014.
//  Copyright (c) 2014, 2015 Rene Hexel. All rights reserved.
//
private let nilCharPtr: UnsafeMutablePointer<CChar>? = nil

/**
 * Convert a swift string (or UnsafePointer<Char>) into
 * an UnsafeMutablePointer<CChar> as used by many POSIX functions.
 * Use with caution: the returned pointer is not really mutable, but many
 * C APIs fail to declare them `const'
 */
func cstring(_ arg: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar> {
    return UnsafeMutablePointer<CChar>(mutating: arg)
}


/**
 * Convert an array of strings into a null-terminated array of 
 * C strings (argument vector)
 * Removing the let/return would be nicer, but crashes:
   public func argv(arguments: [String]) -> [UnsafeMutablePointer<CChar>] {
       return arguments.map { cstring($0) } + [UnsafeMutablePointer<CChar>(nil)]
   }
 */
func argv(_ arguments: [String]) -> [UnsafeMutablePointer<CChar>?] {
    return arguments.map { let s = cstring($0); return s } + [nilCharPtr]
}
