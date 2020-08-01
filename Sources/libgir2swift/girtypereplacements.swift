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
    static private let ints = [cintType, clongType, cshortType, cboolType, cuintType, culongType, cushortType, gintType, glongType, gshortType, guintType, gulongType, gushortType, gsizeType]
        .map { (TypeReference(type: $0), intRef) }
    static private let floats = [floatType, doubleType, gfloatType, gdoubleType]
        .map { (TypeReference(type: $0), doubleRef) }

    /// Idiomatic swift type replacements for return types
    static let swiftReturnTypeReplacements = Dictionary(uniqueKeysWithValues: strings + ints + floats)

    /// Idiomatic swift type replacements for parameters
    static let swiftParameterTypeReplacements = Dictionary(uniqueKeysWithValues: ints + floats)
}
