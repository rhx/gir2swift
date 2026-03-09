import PackagePlugin
import Foundation

/// Plugin error for manifest and GIR discovery failures.
///
/// These cases describe the failure modes encountered while mapping a SwiftPM
/// target to the GIR inputs required by the build tool plugin.
enum Gir2SwiftError: LocalizedError {
    case failedToGetGirNameFromManifest
    case failedToGetGirDirectory(containing: [String])
}

/// Read the GIR name from a manifest file.
///
/// The plugin uses the manifest to identify the primary GIR namespace for the
/// target. The manifest is parsed conservatively because the plugin only needs
/// the `gir-name` field at this stage.
///
/// - Parameter manifest: Manifest path to inspect.
/// - Returns: GIR name declared in `manifest`.
/// - Throws: ``Gir2SwiftError/failedToGetGirNameFromManifest`` when the manifest does not declare a GIR name.
func getGirName(for manifest: Path) throws -> String {
    let lines = try String(contentsOf: URL(fileURLWithPath: manifest.string)).split(separator: "\n")
    var girName: String? = nil
    for line in lines {
        if line.hasPrefix("gir-name: ") {
            girName = line.dropFirst(10).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    if let girName = girName {
        return girName
    } else {
        throw Gir2SwiftError.failedToGetGirNameFromManifest
    }
}

/// Locate the manifest file for a target.
///
/// Target-local manifests take precedence over a package-level manifest. This
/// mirrors the existing plugin behaviour while making the lookup explicit.
///
/// - Parameters:
///   - target: Target whose manifest should be resolved.
///   - targetPackageDirectory: Package directory containing shared configuration files.
/// - Returns: Path to the manifest that should be used for `target`.
func girManifestName(for target: Target, in targetPackageDirectory: Path) -> Path {
    let gir2swiftManifestYaml = "gir2swift-manifest.yaml"
    let gir2swiftTargetDirectoryManifest = target.directory.appending(gir2swiftManifestYaml)
    return FileManager.default.fileExists(atPath: gir2swiftTargetDirectoryManifest.string) ?
            gir2swiftTargetDirectoryManifest : targetPackageDirectory.appending(gir2swiftManifestYaml)
}

/// Find a directory that contains each requested GIR file.
///
/// The plugin searches the standard GIR installation paths and returns the
/// first directory that contains every requested GIR. This keeps dependency
/// resolution deterministic across plugin invocations.
///
/// - Parameter girFiles: GIR file names that must all exist in the same directory.
/// - Returns: Directory path containing every file in `girFiles`.
/// - Throws: ``Gir2SwiftError/failedToGetGirDirectory(containing:)`` when no common directory can be found.
func getGirDirectory(containing girFiles: [String]) throws -> Path {
    let possibleDirectories = ["/opt/homebrew/share/gir-1.0", "/usr/local/share/gir-1.0", "/usr/share/gir-1.0"].map(Path.init(_:))
    for directory in possibleDirectories {
        let directoryContainsAllGirs = girFiles.allSatisfy { file in
            let path = directory.appending(file).string
            return FileManager.default.fileExists(atPath: path)
        }
        if directoryContainsAllGirs {
            return directory
        }
    }
    throw Gir2SwiftError.failedToGetGirDirectory(containing: girFiles)
}

/// Collect target-local input files that affect generation.
///
/// The plugin treats files whose names start with the GIR name as part of the
/// target-specific configuration surface. They are declared as plugin inputs so
/// SwiftPM can re-run the build command when any of them changes.
///
/// - Parameters:
///   - girName: GIR node name that prefixes target-local configuration files.
///   - directory: Target directory to scan.
/// - Returns: Matching input file paths in `directory`.
/// - Throws: Error from `FileManager` if the directory contents cannot be listed.
func existingInputFiles(for girName: String, in directory: Path) throws -> [Path] {
    let directoryURL = URL(fileURLWithPath: directory.string, isDirectory: true)
    let files = try FileManager.default.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    )
    return files.filter { $0.lastPathComponent.hasPrefix(girName) }.map { Path($0.path) }
}

/// The gir2swift build plugin
@main struct Gir2SwiftPlugin: BuildToolPlugin {
    /// Create build commands for GIR-backed Swift targets.
    ///
    /// This method resolves the manifest, declares the GIR and target-local
    /// configuration inputs, predicts the generated output files, and returns a
    /// single build command that drives `gir2swift`.
    ///
    /// - Parameters:
    ///   - context: Plugin context for the current package build.
    ///   - target: Target that declares the `gir2swift` plugin.
    /// - Returns: Build commands required to generate Swift sources for `target`.
    /// - Throws: Error if the manifest or GIR inputs cannot be resolved.
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let targetPackageDirectory = context.package.directory
        let gir2swiftManifest = girManifestName(for: target, in: targetPackageDirectory)
        let outputDir = context.pluginWorkDirectory.appending("gir2swift-generated").appending(target.name)
        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: outputDir.string, withIntermediateDirectories: true)

        let girName = try getGirName(for: gir2swiftManifest)

        // Determine the list of output files
        let atChar = Character("@").utf8.first!
        let suffixes = ["aliases", "bitfields", "callbacks", "constants", "enumerations", "functions", "unions"] +
                       (0...26).map { String(Character(UnicodeScalar(atChar + UInt8($0)))) }
        var outputFiles = suffixes.map { suffix in
            outputDir.appending("\(girName)-\(suffix).swift")
        }

        outputFiles.append(outputDir.appending("\(girName).swift"))

        // Determine the list of input files
        // Find all girs that this library depends on
        let girFiles = target.recursiveTargetDependencies.compactMap {
            let manifest = girManifestName(for: $0, in: targetPackageDirectory)
            return try? getGirName(for: manifest)
        }.filter {
            $0 != girName
        }.map {
            $0 + ".gir"
        }

        let allGirFiles = [girName + ".gir"] + girFiles
        let girDirectory = try getGirDirectory(containing: allGirFiles)
        let inputFiles = try existingInputFiles(for: girName, in: target.directory)
            + [gir2swiftManifest]
            + allGirFiles.map { girDirectory.appending($0) }

        // Construct the arguments
        var arguments = [
            "--alpha-names",
            "-w", targetPackageDirectory.string,
            "-t", target.directory.string,
            "-o", outputDir.string,
        ]

        arguments.append(contentsOf: girFiles.flatMap { girFile in
            ["-p", girDirectory.appending(girFile).string]
        })

        return [.buildCommand(
            displayName: "Converting \(target.directory.lastComponent) \(girName).gir",
            executable: try context.tool(named: "gir2swift").path,
            arguments: arguments,
            inputFiles: inputFiles,
            outputFiles: outputFiles
        )]
    }
}
