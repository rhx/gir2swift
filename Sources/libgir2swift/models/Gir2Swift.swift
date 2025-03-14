//
//  Gir2Swift.swift
//  libgir2swift
//
//  Created by Rene Hexel on 20/5/21.
//  Copyright © 2021, 2022, 2024 Rene Hexel. All rights reserved.
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

    /// The base path for hosting DocC documentation.
    ///
    /// This is the relative path that will be used as the base path
    /// for hosting DocC documentation.
    ///
    /// - Note: Creates relative links if empty.
    @Option(name: .shortAndLong, help: "URL for hosting DocC documentation.")
    var docCHostingBasePath: String = ""

    /// Array of namespaces (implemented as extensions to existing types) to add global structs, classes, and protocols to.
    @Option(name: .shortAndLong, help: "Add a namespace extension with the given name.")
    var extensionNamespace: [String] = []

    /// Array of namespaces to add global structs, classes, and protocols to.
    @Option(name: .shortAndLong, help: "Add a namespace with the given name.")
    var namespace: [String] = []

    /// Create a single output file per class if `true`
    @Flag(name: .short, help: "Create a single .swift file per class.")
    var singleFilePerClass = false

    /// Array of extra files to post-process.
    @Option(name: .long, help: "Additional files to post-process.")
    var postProcess: [String] = []

    /// Array of names of pre-parsed `.gir` files.
    @Option(name: .short, help: "Add pre-requisite .gir files to ensure the types in file.gir are known. Prerequisities specified in CLI are merged with the prerequisites found by gir2swift.")
    var prerequisiteGir: [String] = []

    /// Name of the output directory to write generated files to.
    /// - Note: Writes generated code to `standardOutput` if empty
    @Option(name: .short, help: "Specify the output directory to put the generated files into.")
    var outputDirectory: String = ""

    /// Name of the target source code directory to read configurations from.
    /// - Note: Will use the current working directory if empty
    @Option(name: .shortAndLong, help: "Specify the target source directory to read the manifest and configurations from.")
    var targetDirectory: String = ""

    /// Name of the working directory to operate within.
    /// - Note: Will use the current working directory if empty
    @Option(name: .shortAndLong, help: "Specify the working directory (package directory of the target) to change into.")
    var workingDirectory: String = ""

    /// Name of the library to pass to pkg-config
    /// - Note: Defaults to the lower-cased name of the `.gir` file
    @Option(name: .long, help: "Library name to pass to pkg-config. Pkg config name specified in CLI trumps the one found in manifest.")
    var pkgConfigName: String?

    /// File containing one-off boilerplate code for your module
    @Option(name: .short, help: "Add the given .swift file as the main (hand-crafted) Swift file for your library target.")
    var moduleBoilerPlateFile: String = ""

    /// By default, the gir2swift searches for manifest in the work directory. As for now, the search can't be sidabled.
    @Option(name: .long, help: "Custom path to manifest.")
    var manifest: String = "gir2swift-manifest.yaml"

    /// The actual, main `.gir` file(s) to process
    @Argument(help: "The .gir metadata files to process. Gir files specified in CLI are merged with those specified in the manifest.")
    var girFiles: [String] = []

    /// Skips all other generations steps and prints opaque struct stylized declarations for each record and class to stdout.
    @Flag(name: .long, help: "Skips all other generations steps and prints opaque struct stylized declarations for each record and class to stdout.")
    var opaqueDeclarations: Bool = false

    /// Designated initialiser
    public init() {}
    
    /// Main function to run the `gir2swift command`
    mutating public func run() throws {
        let fileManager = FileManager.default
        guard workingDirectory.isEmpty || fileManager.changeCurrentDirectoryPath(workingDirectory) else {
            fatalError("Cannot change into '\(workingDirectory)': \(String(cString: strerror(errno)))")
        }

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

        var girsToPreload = Set(prerequisiteGir)
        var girFilesToGenerate = Set(girFiles)

        // This variable is a dead store
        var pkgConfig = pkgConfigName

        let manifestPlan: Plan?
        let manifestURL: URL
        let targetDirectoryURL: URL
        let wd = fileManager.currentDirectoryPath
        let wdURL = URL(fileURLWithPath: wd)
        if #available(macOS 10.11, *) {
            let targetURL = targetDirectory.isEmpty ? wdURL : URL(fileURLWithPath: targetDirectory, isDirectory: true, relativeTo: wdURL)
            let targetManifest = URL(fileURLWithPath: manifest, relativeTo: targetURL)
            if fileManager.fileExists(atPath: targetManifest.path) {
                targetDirectoryURL = targetURL
                manifestURL = targetManifest
            } else {
                targetDirectoryURL = wdURL
                manifestURL = URL(fileURLWithPath: manifest, relativeTo: wdURL)
            }
        } else {
            let targetURL = targetDirectory.isEmpty ? wdURL : wdURL.appendingPathComponent(targetDirectory)
            let targetManifest = targetURL.appendingPathComponent(manifest)
            if fileManager.fileExists(atPath: targetManifest.path) {
                targetDirectoryURL = targetURL
                manifestURL = targetManifest
            } else {
                targetDirectoryURL = wdURL
                manifestURL = wdURL.appendingPathComponent(manifest)
            }
        }
        do {
            let plan = try Plan(using: manifestURL, isVerbose: verbose)
            girsToPreload.formUnion(plan.girFilesToPreload.map(\.path))
            girFilesToGenerate.insert(plan.girFileToGenerate.path)
            pkgConfig = pkgConfig ?? plan.pkgConfigName
            for ns in plan.namespaces {
                guard !namespace.contains(ns) else { continue }
                namespace.append(ns)
            }
            manifestPlan = plan
        } catch {
            manifestPlan = nil
            print("Failed to load \(manifestURL.path) for \(girFilesToGenerate.map { ($0.split(separator: "/").last ?? "").split(separator: ".").first ?? "" }.joined(separator: ", ")) manifest\(girFilesToGenerate.count > 1 ? "s" : ""):\n    \(error)", to: &Streams.stdErr)
        }

        // pre-load gir files to ensure pre-requisite types are known
        for girFile in girsToPreload {
            preload_gir(file: girFile)
        }

        let target = outputDirectory.isEmpty ? manifestPlan?.outputDirectory : outputDirectory
        let generateAlphaFiles = alphaNames || manifestPlan?.useAlphaNames ?? false

        switch opaqueDeclarations {
        case true:
            for girFile in girFilesToGenerate {
                process_gir_to_opaque_decls(file: girFile, in: targetDirectoryURL, generateAll: allFilesGenerate)
            }
        case false:
            for girFile in girFilesToGenerate {
                process_gir(file: girFile, for: targetDirectoryURL, boilerPlate: moduleBoilerPlate, to: target, docCHostingBasePath: docCHostingBasePath, split: singleFilePerClass, generateAll: allFilesGenerate, useAlphaNames: generateAlphaFiles, postProcess: postProcess + (manifestPlan?.postProcess ?? []), pkgConfig: pkgConfig)
            }
        }

        if verbose {
            let nTypesAfter = GIR.knownTypes.count
            let nTypesAdded = nTypesAfter - nTypesPrior
            print("Processed \(nTypesAdded) types (total: \(nTypesAfter)).")
        }
    }
}

