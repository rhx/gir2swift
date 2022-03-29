import Foundation
import PackagePlugin

extension Path {
    func exists() -> Bool {
        FileManager.default.fileExists(atPath: string)
    }
}

let module = targetBuildContext.moduleName
let outputDir = targetBuildContext.outputDirectory.appending("Generated")

let output = outputDir.appending("Output.swift")

func packageDirectory(for target: Path) -> Path {
    var curr = target
    while !curr.appending("Package.swift").exists() {
        if curr.stem.isEmpty {
            fatalError("Could not find Package.swift for target \(target)")
        }
        curr = curr.removingLastComponent()
    }
    return curr
}

let girNames = try targetBuildContext.dependencies.compactMap { target -> String? in
    let package = packageDirectory(for: target.targetDirectory)
    let manifest = package.appending("gir2swift-manifest.sh")
    guard manifest.exists() else { return nil }

    let pipe = Pipe()

    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: manifest.string)
    proc.arguments = ["gir-name"]
    proc.standardOutput = pipe
    try proc.run()

    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

let girSearchPaths: [Path] = ["/opt/homebrew/share/gir-1.0", "/usr/local/share/gir-1.0", "/usr/share/gir-1.0"]
guard let girPath = girSearchPaths.first(where: { searchPath in
    girNames.allSatisfy { gir in searchPath.appending("\(gir).gir").exists() }
}) else {
    fatalError("Could not locate GIR path")
}

let girFiles = girNames.map { girPath.appending("\($0).gir") }

commandConstructor.createBuildCommand(
    displayName: "Running gir2swift",
    executable: targetBuildContext.packageDirectory.appending("gir2swift-manifest.sh"),
    arguments: [
        "generate",
        // packagePath
        targetBuildContext.packageDirectory.string,
        // g2s_exec
        try targetBuildContext.tool(named: "gir2swift").path.string,
        // gir_pre
        girNames.dropFirst().joined(separator: " "),
        // gir_path
        girPath.string,
        // output_dir
        outputDir.string
    ],
    inputFiles: girFiles,
    outputFiles: [output]
)
