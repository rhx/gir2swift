import PackagePlugin
import Foundation

/// The gir2swift build plugin
@main
struct GIR2SwiftPlugin: BuildToolPlugin {
    /// A Plugin that generates Swift code from a `.gir` FILE
    /// - Parameters:
    ///   - context: information about the package for which the plugin is provided
    ///   - target: the target defined in the package
    /// - Returns: the commands to run during the build
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let targetPackageDirectory = context.package.directory
        let gir2swiftManifest = targetPackageDirectory.appending("gir2swift-manifest.yaml")
        let gir2swiftOutputs = context.pluginWorkDirectory.appending("gir2swift-generated").appending(target.name)
        try FileManager.default.createDirectory(atPath: gir2swiftOutputs.string, withIntermediateDirectories: true)
        return [.prebuildCommand(
            displayName: "Running gir2swift",
            executable: try context.tool(named: "gir2swift").path,
            arguments: [
                "-w", targetPackageDirectory,
                "-o", gir2swiftOutputs,
                "--manifest", "\(gir2swiftManifest)"
            ],
            environment: [
                "PROJECT_DIR": "\(targetPackageDirectory)",
                "TARGET_NAME": "\(target.name)",
                "DERIVED_SOURCES_DIR": "\(gir2swiftOutputs)",
            ],
            outputFilesDirectory: gir2swiftOutputs)
        ]
    }
}

