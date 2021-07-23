//
//  Gir2Swift.swift
//  libgir2swift
//
//  Created by Rene Hexel on 20/5/21.
//  Copyright © 2021 Rene Hexel. All rights reserved.
//
import ArgumentParser
import Foundation

/// Structure representing the `gir2swift` executable, including command line arguments
public struct Gir2Swift: ParsableCommand {
    /// Produce verbose output if `true`
    @Flag(name: .short, help: "Produce verbose output.")
    var verbose = false

    /// Generate output for everything, including private C types if `true`
    @Flag(name: .short, help: "Disables all filters. Wrappers for all C types will be generated.")
    var allFilesGenerate = false

    /// Create a fixed set of output files ending in A-Z if `true`
    @Flag(name: .long, help: "Create a fixed set of output files ending in A-Z.")
    var alphaNames = false

    /// Create a single output file per class if `true`
    @Flag(name: .short, help: "Create a single .swift file per class.")
    var singleFilePerClass = false

    /// Array of names of pre-parsed `.gir` files.
    @Option(name: .short, help: "Add pre-requisite .gir files to ensure the types in file.gir are known.")
    var prerequisiteGir: [String] = []

    /// Name of the output directory to write generated files to.
    /// - Note: Writes generated code to `standardOutput` if `nil`
    @Option(name: .short, help: "Specify the output directory to put the generated files into.")
    var outputDirectory: String = ""

    /// Name of the library to pass to pkg-config
    /// - Note: Defaults to the lower-cased name of the `.gir` file
    @Option(name: .long, help: "Library name to pass to pkg-config.")
    var pkgConfigName: String?

    /// File containing one-off boilerplate code for your module
    @Option(name: .short, help: "Add the given .swift file as the main (hand-crafted) Swift file for your library target.")
    var moduleBoilerPlateFile: String = ""

    /// The actual, main `.gir` file(s) to process
    @Argument(help: "The .gir metadata files to process.")
    var girFiles: [String]
    
    /// Designated initialiser
    public init() {}
    
    /// Main function to run the `gir2swift command`
    mutating public func run() throws {
        let nTypesPrior = GIR.knownTypes.count

        let moduleBoilerPlate: String
        if moduleBoilerPlateFile.isEmpty {
            moduleBoilerPlate = moduleBoilerPlateFile
        } else {
            guard let contents = try? String(contentsOfFile: moduleBoilerPlateFile, encoding: .utf8) else {
                fatalError("Cannot read contents of '\(moduleBoilerPlateFile)'")
            }
            moduleBoilerPlate = contents
        }

        // pre-load gir files to ensure pre-requisite types are known
        for girFile in prerequisiteGir {
            preload_gir(file: girFile)
        }

        let target = outputDirectory.isEmpty ? nil : outputDirectory
        for girFile in girFiles {
            process_gir(file: girFile, pkgConfigName: pkgConfigName, boilerPlate: moduleBoilerPlate, to: target, split: singleFilePerClass, generateAll: allFilesGenerate, useAlphaNames: alphaNames)
        }

        if verbose {
            let nTypesAfter = GIR.knownTypes.count
            let nTypesAdded = nTypesAfter - nTypesPrior
            print("Processed \(nTypesAdded) types (total: \(nTypesAfter)).")
        }
    }
}

