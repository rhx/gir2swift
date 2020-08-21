//
//  girtypereplacements.swift
//  libgir2swift
//
//  Created by Rene Hexel on 2/8/20.
//  Copyright © 2020 Rene Hexel. All rights reserved.
//
import Foundation

public extension GIR {
    static private let strings = [ charPtr, constCharPtr, gcharPtr, constGCharPtr, gucharPtr, constGUCharPtr ]
        .map { ($0, stringRef) }
    static private let rawCharPtrs = [ utf8Ref, constUTF8Ref, fileRef, constFileRef ]
        .map { ($0, constCharPtr) }
    static private let rawStrings = [ utf8Ref, constUTF8Ref, fileRef, constFileRef ]
        .map { ($0, stringRef) }
    static private let ints = [cintType, clongType, cshortType, cuintType, culongType, cushortType, gintType, gintAlias, glongType, glongAlias, gshortType, gshortAlias, guintType, guintAlias, gulongType, gulongAlias, gushortType, gushortAlias, gsizeType]
        .map { (TypeReference(type: $0), intRef) }
    static private let floats = [floatType, doubleType, gfloatType, gdoubleType]
        .map { (TypeReference(type: $0), doubleRef) }
    static private let bools = [gbooleanType, cboolType].map { (TypeReference(type: $0), boolRef) }
    static private let gpointers = [ (gpointerRef, forceUnwrappedGPointerRef), (gconstpointerRef, forceUnwrappedGConstPointerRef)]
    static private let gpointerPointers = [
        (gpointerPointerRef, optionalGPointerPointerRef),
        (gpointerMutablePointerRef, optionalGPointerMutablePointerRef),
        (gconstpointerPointerRef, optionalGConstpointerPointerRef),
        (gconstpointerMutablePointerRef, optionalGConstpointerMutablePointerRef),
        (gpointerConstPointerRef, forceUnwrappedGConstPointerRef)
    ]
    /// Fundamental swift type replacements required for the compiler
    static let swiftFundamentalReplacements = Dictionary(uniqueKeysWithValues: gpointerPointers)

    /// Idiomatic swift type replacements for return types
    static let swiftReturnTypeReplacements = Dictionary(uniqueKeysWithValues: strings + rawStrings + ints + floats + bools + gpointers + gpointerPointers)

    /// Idiomatic swift type replacements for parameters
    static let swiftParameterTypeReplacements = Dictionary(uniqueKeysWithValues: ints + floats + bools + rawCharPtrs + gpointers + gpointerPointers)

    /// Mapping of gir type names to Swift names for underlying C types
    static let underlyingPrimitiveSwiftTypes = [ utf8: CChar, filename: CChar ]
}
