import PackagePlugin
import Foundation

/// Type representing a plugin error
enum Gir2SwiftError: LocalizedError {
    case failedToGetGirNameFromManifest
    case failedToGetGirDirectory(containing: [String])
}

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

func girManifestName(for target: Target, in targetPackageDirectory: Path) -> Path {
    let gir2swiftManifestYaml = "gir2swift-manifest.yaml"
    let gir2swiftTargetDirectoryManifest = target.directory.appending(gir2swiftManifestYaml)
    return FileManager.default.fileExists(atPath: gir2swiftTargetDirectoryManifest.string) ?
            gir2swiftTargetDirectoryManifest : targetPackageDirectory.appending(gir2swiftManifestYaml)
}

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

/// The gir2swift build plugin
@main struct Gir2SwiftPlugin: BuildToolPlugin {
    /// A Plugin that generates Swift code from a `.gir` FILE
    /// - Parameters:
    ///   - context: information about the package for which the plugin is provided
    ///   - target: the target defined in the package
    /// - Returns: the commands to run during the build
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
        let targetDir = URL(fileURLWithPath: target.directory.string)
        let contents = try fileManager.contentsOfDirectory(at: targetDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants])
        let inputFiles = contents.filter { file in
            file.lastPathComponent.hasPrefix(girName)
        }.map { file in
            Path(file.path)
        } + [gir2swiftManifest]

        // Find all girs that this library depends on
        let girFiles = target.recursiveTargetDependencies.compactMap {
            let manifest = girManifestName(for: $0, in: targetPackageDirectory)
            return try? getGirName(for: manifest)
        }.filter {
            $0 != girName
        }.map {
            $0 + ".gir"
        }

        let girDirectory = try getGirDirectory(containing: girFiles)

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
            displayName: "Converting \(girName) for \(target.directory.lastComponent)",
            executable: try context.tool(named: "gir2swift").path,
            arguments: arguments,
            inputFiles: inputFiles,
            outputFiles: outputFiles
        )]
    }
}
