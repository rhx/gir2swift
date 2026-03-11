//
//  generation.swift
//  gir2swift
//
//  Created by Rene Hexel on 10/3/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// Fixed output suffixes for generated support files.
///
/// These suffixes correspond to generated files whose names do not depend on
/// individual GIR records. They are used when predicting the output set for
/// incremental generation checks.
private let fixedGeneratedSuffixes = [
    "aliases",
    "bitfields",
    "callbacks",
    "constants",
    "enumerations",
    "functions",
    "unions",
]

/// Target-local configuration suffixes that influence generation behaviour.
///
/// Files with these suffixes are treated as generation inputs when their names
/// start with the current GIR node. Changes to any of them should force the
/// generated Swift output to be reconsidered.
private let nodeConfigurationSuffixes = [
    ".awk",
    ".blacklist",
    ".callbackSuffixes",
    ".cat",
    ".exclude",
    ".include",
    ".module",
    ".namespaceReplacements",
    ".override",
    ".preamble",
    ".sed",
    ".typedCollections",
    ".verbatim",
    ".whitelist",
]

/// Return the modification date for a file URL.
///
/// The returned date is used for make-style staleness checks. If the resource
/// values cannot be read, the function returns `nil` so the caller can fall
/// back to regenerating output.
///
/// - Parameter url: File URL for the item to inspect.
/// - Returns: Content modification date for `url`, or `nil` if it cannot be read.
private func modificationDate(for url: URL) -> Date? {
    guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]) else {
        return nil
    }
    return values.contentModificationDate
}

/// Indicate whether a file name represents a version-qualified Swift input file.
///
/// Version-qualified Swift inputs are appended during post-processing and are
/// therefore part of the effective input and output set for a GIR node. This
/// helper recognises the naming conventions already used by the post-processing
/// pipeline.
///
/// - Parameters:
///   - fileName: File name to inspect.
///   - node: GIR node prefix that the file must match.
/// - Returns: `true` if `fileName` matches a supported version-qualified Swift input pattern.
private func isVersionedSwiftInputFile(named fileName: String, node: String) -> Bool {
    guard fileName.hasPrefix(node), fileName.hasSuffix(".swift") else {
        return false
    }
    let start = fileName.startIndex
    let end = fileName.endIndex
    guard let separator = fileName.index(fileName.startIndex, offsetBy: node.count, limitedBy: fileName.endIndex),
          separator != end,
          let versionEnd = fileName.index(fileName.endIndex, offsetBy: -(".swift".count + 1), limitedBy: fileName.startIndex),
          versionEnd != start else {
        return false
    }
    let separatorCharacter = fileName[separator]
    let next = fileName.index(after: separator)
    guard next < end else { return false }
    let nextCharacter = fileName[next]
    let versionStart: String.Index
    switch (separatorCharacter, nextCharacter) {
    case ("-", _) where nextCharacter.isDigit:
        versionStart = next
    case ("=", _) where nextCharacter.isDigit:
        versionStart = next
    case (">", "="), ("+", "="), ("<", "="), ("-", "="):
        let candidate = fileName.index(after: next)
        guard candidate < versionEnd, fileName[candidate].isDigit else { return false }
        versionStart = candidate
    default:
        return false
    }
    return versionStart <= versionEnd
}

/// Collect the configured input files for incremental generation.
///
/// The returned list includes the main GIR file, prerequisite GIR files, the
/// manifest, target-local configuration files, and explicitly supplied
/// post-processing inputs. Missing files are discarded so the caller can base
/// the rebuild decision on the files that are currently present.
///
/// - Parameters:
///   - node: GIR node name without the file extension.
///   - girFile: Path to the main GIR file.
///   - prerequisiteGirFiles: Paths to prerequisite GIR files.
///   - manifestURL: URL for the manifest file, if one is in use.
///   - moduleBoilerPlateFile: Path to the module boilerplate file.
///   - targetDirectoryURL: URL for the target directory containing configuration files.
///   - additionalInputFiles: Extra input files supplied on the command line or via the manifest.
/// - Returns: Existing input file URLs that affect generation behaviour.
func configuredGenerationInputs(
    node: String,
    girFile: String,
    prerequisiteGirFiles: [String],
    manifestURL: URL?,
    moduleBoilerPlateFile: String,
    targetDirectoryURL: URL,
    additionalInputFiles: [String]
) -> [URL] {
    let fileManager = FileManager.default
    let targetDirectoryFiles = ((try? fileManager.contentsOfDirectory(
        at: targetDirectoryURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    )) ?? []).filter { file in
        let fileName = file.lastPathComponent
        guard fileName.hasPrefix(node) else { return false }
        return nodeConfigurationSuffixes.contains(where: fileName.hasSuffix)
            || isVersionedSwiftInputFile(named: fileName, node: node)
    }

    let explicitInputFiles = additionalInputFiles.map { file in
        if URL(fileURLWithPath: file).isFileURL && file.hasPrefix("/") {
            return URL(fileURLWithPath: file)
        }
        return URL(fileURLWithPath: file, relativeTo: targetDirectoryURL)
    }

    let moduleBoilerPlateURL: URL? = moduleBoilerPlateFile.isEmpty ? nil : {
        if moduleBoilerPlateFile.hasPrefix("/") {
            return URL(fileURLWithPath: moduleBoilerPlateFile)
        }
        return URL(fileURLWithPath: moduleBoilerPlateFile, relativeTo: URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true))
    }()

    let girInputs = ([girFile] + prerequisiteGirFiles).map { file -> URL in
        if file.hasPrefix("/") {
            return URL(fileURLWithPath: file)
        }
        return URL(fileURLWithPath: file, relativeTo: URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true))
    }

    return Array(Set(targetDirectoryFiles + explicitInputFiles + girInputs + [manifestURL, moduleBoilerPlateURL].compactMap { $0 }))
    .filter { fileManager.fileExists(atPath: $0.path) }
}

/// Predict the generated output files for incremental generation.
///
/// The returned URLs cover the fixed generated files, alphabetically split
/// output files when requested, optional namespace output, and any
/// version-qualified Swift files that are copied into the output directory
/// during post-processing.
///
/// - Parameters:
///   - node: GIR node name without the file extension.
///   - outputDirectory: Output directory used for generated Swift files.
///   - useAlphaNames: Flag indicating whether fixed alphabetical output files are expected.
///   - hasNamespaceOutput: Flag indicating whether namespace output should be generated.
///   - targetDirectoryURL: URL for the target directory containing configuration files.
/// - Returns: Output file URLs that should exist when generation is current.
func expectedGeneratedOutputs(
    node: String,
    outputDirectory: String,
    useAlphaNames: Bool,
    hasNamespaceOutput: Bool,
    targetDirectoryURL: URL
) -> [URL] {
    let fileManager = FileManager.default
    let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
    let outputDirectoryURL = URL(fileURLWithPath: outputDirectory, isDirectory: true, relativeTo: currentDirectoryURL)
    let versionedSwiftOutputs = ((try? fileManager.contentsOfDirectory(
        at: targetDirectoryURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    )) ?? []).filter {
        isVersionedSwiftInputFile(named: $0.lastPathComponent, node: node)
    }.map {
        outputDirectoryURL.appendingPathComponent($0.lastPathComponent, isDirectory: false)
    }

    var outputs = fixedGeneratedSuffixes.map {
        outputDirectoryURL.appendingPathComponent("\(node)-\($0).swift", isDirectory: false)
    }
    outputs.append(outputDirectoryURL.appendingPathComponent("\(node).swift", isDirectory: false))
    outputs.append(contentsOf: versionedSwiftOutputs)
    if hasNamespaceOutput {
        outputs.append(outputDirectoryURL.appendingPathComponent("\(node)-namespaces.swift", isDirectory: false))
    }
    if useAlphaNames {
        let atChar = Character("@").utf8.first!
        outputs.append(contentsOf: (0...26).map { index in
            let suffix = String(Character(UnicodeScalar(atChar + UInt8(index))))
            return outputDirectoryURL.appendingPathComponent("\(node)-\(suffix).swift", isDirectory: false)
        })
    } else {
        let existingOutputs = ((try? fileManager.contentsOfDirectory(
            at: outputDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )) ?? []).filter { file in
            let fileName = file.lastPathComponent
            return fileName == "\(node).swift"
                || (fileName.hasPrefix("\(node)-") && fileName.hasSuffix(".swift"))
        }
        outputs.append(contentsOf: existingOutputs)
    }
    return Array(Set(outputs))
}

/// Decide whether generated output should be rebuilt.
///
/// This function compares the newest available input timestamp with the oldest
/// available output timestamp. It treats missing outputs, unreadable
/// modification dates, and explicit overwrite requests as reasons to rebuild.
///
/// - Parameters:
///   - inputFiles: Input file URLs that influence generation.
///   - outputFiles: Output file URLs expected from generation.
///   - overwrite: Flag indicating whether regeneration should be forced.
/// - Returns: `true` if generation should run, otherwise `false`.
func shouldGenerateOutputs(inputFiles: [URL], outputFiles: [URL], overwrite: Bool) -> Bool {
    guard !overwrite else { return true }
    guard !outputFiles.isEmpty else { return true }

    let fileManager = FileManager.default
    guard outputFiles.allSatisfy({ fileManager.fileExists(atPath: $0.path) }) else {
        return true
    }

    let inputDates = inputFiles.compactMap(modificationDate(for:))
    guard let newestInput = inputDates.max() else {
        return true
    }

    let outputDates = outputFiles.compactMap(modificationDate(for:))
    guard outputDates.count == outputFiles.count, let oldestOutput = outputDates.min() else {
        return true
    }

    return oldestOutput < newestInput
}
