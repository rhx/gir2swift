import Foundation
import Yams
import SwiftLibXML

/// Declaration of the manifest contents.
struct Manifest: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case girName = "gir-name"
        case pkgConfig = "pkg-config"
        case outputDirectory = "output-directory"
        case alphaNames = "alpha-names"
        case prerequisites
        case postProcess = "post-process"
    }

    /// The version of manifest. It is not utilized now, but I want to keep the property there for future purposes.
    let version: UInt

    /// The name of the gir file associated with the manifest. Extension is NOT expected.
    let girName: String

    /// The name of pkg-config package in which the gir file resides.
    /// If this is `nil`, then the lowercase version of the gir name will be used.
    let pkgConfig: String?

    /// The output directory for the generated files
    let outputDirectory: String?

    /// output alphabetical names
    let alphaNames: Bool?

    /// Optional list of `.gir` prerequisites
    let prerequisites: [Prerequisite]?

    /// Optional list of  files to postprocess
    let postProcess: [String]?
}

/// Description of a `.gir` prerequisite
struct Prerequisite: Codable {
    private enum CodingKeys: String, CodingKey {
        case girName = "gir-name"
        case pkgConfig = "pkg-config"
    }

    /// Gir file name associated with the prerequisity. Extension is NOT expected.
    let girName: String

    /// The name of pkg-config package in which the gir file resides (mainly for the purposes of macOS sandboxing)
    /// If this is `nil`, then the lowercase version of the gir name will be used.
    let pkgConfig: String?
}

/// Metadata parsed from a `.gir` file. This structure is intended to help in determining the dependency graph of `.gir` files. It represents the contents of `/gir:repository`
struct GirPackageMetadata {
    struct Dependency {
        let name: String
        let version: String

        var girName: String { name + "-" + version }
    }

    /// Package name corresponding to `pkg-config`. Represents the contents of `/gir:repository/gir:package`
    let pkgName: String
    
    ///Dependency required for preload before generation if this `.gir` file. Represents the contents of `/gir:repository/gir:include`
    let dependency: [Dependency]
}

/// Structure, that is used to determine generation process.
struct Plan {

    enum Error: Swift.Error {
        case girNotFound(named: String)
        case girParsingFailed
    }

    /// The path to `.gir` file that shall be generated
    let girFileToGenerate: URL

    /// The paths to prerequisites of the `.gir` file
    let girFilesToPreload: [URL]
    
    /// Pkg config name of the generated package
    let pkgConfigName: String

    /// The output directory for the generated files
    let outputDirectory: String?

    /// output alphabetical names
    let useAlphaNames: Bool

    /// Creates generation plan by reading `.yaml` manifest. The strucuture of the manifest is
    /// described by structure `Manifest`.
    ///
    /// After contents of the `.yaml` are parsed, the initializer then parses the `.gir` files and
    /// consults `pkg-config` in order to determine the dependency graph of the `.gir` files
    /// and their location.
    ///
    /// - Note: On macOS, the `.gir` files are located in separate folders, therefore we need
    /// to consult the `pkg-config` out of necessity, because this is the only way we can learn the
    /// potential location of the gir files.
    ///
    /// - Parameter manifestURL: Path to manifest
    /// - Throws: Error may represent various error states, differing from the inability to read
    /// the `.yaml` file, a `.gir` file or error during consulting `pkg-config`.
    init(using manifestURL: URL) throws {
        let data = try Data(contentsOf: manifestURL, options: .mappedIfSafe)
        let manifest = try YAMLDecoder().decode(Manifest.self, from: data)
        let pkgConfig = manifest.pkgConfig ?? manifest.girName.lowercased()
        
        // Search for location of the generated `.gir` file.
        let optGirPath = try Plan.searchForGir(
            named: manifest.girName, 
            pkgConfig: [pkgConfig]
        )
        guard let girPath = optGirPath else {
            throw Error.girNotFound(named: manifest.girName + ".gir" )
        } 

        self.girFileToGenerate = girPath
        self.girFilesToPreload = try Plan.loadPrerequisities(from: girPath, pkgConfig: pkgConfig, prerequisites: manifest.prerequisites)
        self.pkgConfigName = pkgConfig
        self.outputDirectory = manifest.outputDirectory
        self.useAlphaNames = manifest.alphaNames ?? false
    }
    
    /// Searches for `.gir` file location for given name.
    /// - Parameters:
    ///   - name: The name of the `.gir` file WITHOUT extension
    ///   - pkgConfig: Names of pkg-config packages that should be explored too. This is done on macOS only.
    /// - Returns: Location of the `.gir` file, if found.
    private static func searchForGir(named name: String, pkgConfig: Set<String>) throws -> URL? {
        // Common locations of `.gir` files on different platforms
        let defaultPaths = ["/opt/homebrew/share/gir-1.0", "/usr/local/share/gir-1.0", "/usr/share/gir-1.0"].map { URL(fileURLWithPath: $0, isDirectory: false) }
        
        var searchPaths = defaultPaths
        #if os(macOS)
        // Path relative to the `libdir` variable of the package, where the `.gir` files are commonly located. This path is arbitrary!
        let homebrewRelativeGirLocation = "../share/gir-1.0/"
        // All pkg-config packages passed in the argument are scanned and their `libdir` values are reported.
        // TODO: This is major performance hit. Optimization desirable.
        let homebrewPaths = pkgConfig.compactMap { pkgName -> URL? in 
            let libDir = try? executeAndWait("env", arguments: ["pkg-config", "--variable=libdir", pkgName])
            return libDir.flatMap { 
                let libDirUrl = URL(fileURLWithPath: $0, isDirectory: true)
                return URL(string: homebrewRelativeGirLocation, relativeTo: libDirUrl)
            }
        }

        searchPaths = homebrewPaths + defaultPaths
        #endif

        // After all search paths are determined, we search for the first appearance of a `.gir` file with corresponding name.
        return searchPaths
            .map { $0.appendingPathComponent(name).appendingPathExtension("gir") }
            .first { 
                FileManager.default.fileExists(atPath: $0.path) 
            }
    }
    
    /// This function the overall driver of the dependency graph generation. It searches the `pkg-config` dependency
    /// graph to get all required `pkg-config` packages which may contain a `.gir` file and then parses the `.gir`
    /// files in order to get list of all names of `.gir` files that will be required. If a location of any `.gir` file can not be
    /// determined, the functions throws an error.
    ///
    /// - Parameters:
    ///   - gir: Path to root gir file.
    ///   - pkgConfig: Name of `pkg-config` package which corresponds to the root `.gir` file.
    ///   - prerequisites: Additional prerequisites alongside with their `pkg-config` package names specified in the manifest.
    /// - Returns: List of locations of `.gir` files that have to be preloaded.
    private static func loadPrerequisities(from gir: URL, pkgConfig: String, prerequisites: [Prerequisite]?) throws -> [URL] {
        // We do not want to list the root `.gir` file as explored, since it is not it's own dependency. (Having the gir file in the list would break the generation process.)
        var explored: [String: URL] = [:]
        // The root `.gir` file is parsed and it's dependencies are scheduled for exploration. Also any prerequisited are scheduled for exploration.
        var toExplore: Set<String> = Set(try parsePackageInfo(for: gir).dependency.map(\.girName) + (prerequisites?.map(\.girName) ?? []))

        // This set is used to store names of `pkg-config` packages, that may contain a `.gir` file.
        // This is needed only on macOS since it is the only supported platform where the `.gir`
        // files are not located in a single directory.
        var pkgConfigCandidates: Set<String> = []
        #if os(macOS)
            // Determine the dependency graph of `pkg-config` and add them all to the candidate set.
            for package in (prerequisites?.map({$0.pkgConfig ?? $0.girName.lowercased()}) ?? []) + [pkgConfig] {
                pkgConfigCandidates.formUnion(try getAllPkgConfigDependencies(for: package))
            }
        #endif

        // Continue parsing `.gir` files and search their dependencies, until no more are to be
        // searched.
        while !toExplore.isEmpty {
            let executing = toExplore.removeFirst()
            // If a `.gir` file can not be found, end.
            guard let url = try searchForGir(named: executing, pkgConfig: pkgConfigCandidates) else {
                throw Error.girNotFound(named: executing)
            }

            explored[executing] = url

            // Add all `.gir` files that were not already explored to the exploration list.
            let packageInfo = try parsePackageInfo(for: url)
            packageInfo.dependency.forEach { dependency in
                if explored[dependency.girName] == nil {
                    toExplore.insert(dependency.girName)
                }
            }
        }

        // Ensure, that the root `.gir` file is not listed as it's own dependency. This
        // step might be needed, in case that circular dependency is present.
        return explored
            .filter { $1.lastPathComponent != gir.lastPathComponent }
            .map(\.value)
    }
    
    /// This function performs "deep search" using `pkg-config` in order to get all packages that
    /// are needed by this package and it's dependencies.
    /// - Parameter package: The root `pkg-config` package name
    /// - Returns: Set of all dependencies.
    private static func getAllPkgConfigDependencies(for package: String) throws -> Set<String> {
        var explored: Set<String> = []
        var toExplore: Set<String> = [package]

        // Call `pkg-config` until it was called once for all searched packages.
        while !toExplore.isEmpty {
            let executing = toExplore.removeFirst()
            explored.insert(executing)

            try getPkgConfigDependencies(for: executing).forEach { result in
                // Schedule all dependencies of the `pkg-config` package
                // to be explored unless a dependency was already explored.
                if !explored.contains(result) {
                    toExplore.insert(result)
                }
            }
        }

        return explored
    }
    
    /// Get other `pkg-config` packages, that the specified package depends on. The `pkg-config` won't
    /// perform a "deep search" of the dependency graph.
    /// - Parameter package: The name of the `pkg-config` package.
    /// - Returns: The list of dependencies.
    private static func getPkgConfigDependencies(for package: String) throws -> [String] {
        guard let output = try executeAndWait("env", arguments: ["pkg-config", "--print-requires", package]) else {
            return []
        }

        // Each dependency is on separate line
        let dependecyRecord = output.components(separatedBy: .newlines)
        // If the pkg-config package requires specific version, the version is specified
        // on the same line separated by whitespace. We don't need this information, we
        // only need the name of the package.
        let packageNames = dependecyRecord.compactMap { line in
            line.components(separatedBy: .whitespaces).first
        }

        // If package has no dependencies, empty string is returned. We need to get rid of it.
        return packageNames.filter { !$0.isEmpty }
    }
    
    /// This function parses the `.gir` file using libxml2 in order to get dependency metadata from the `.gir` file.
    /// - Parameter gir: The location of the `.gir` file.
    private static func parsePackageInfo(for gir: URL) throws -> GirPackageMetadata {
        guard let xml = XMLDocument(fromFile: gir.path) else {
            throw Error.girNotFound(named: gir.lastPathComponent)
        }

        // @rhx please check this code
        // This operation might be expansive, however the element `repository` is usualy the first.
        // We need to do this, because before namespaces are loaded, the xpath does not work.
        if let repository = xml.first(where: { $0.name == "repository" }) {
            // Load namespaces
            let namespaces = repository.namespaces

            // Search for first occurance of `package` element. We expect only one package - we do not expect that a `.gir` file describes multiple pkg-config packages.
            guard 
                let packageName = xml.xpath(
                    "/gir:repository/gir:package", 
                    namespaces: namespaces, 
                    defaultPrefix: "gir"
                )?.first?.attribute(named: "name") 
            else { throw Error.girParsingFailed }

            // Search for all occurances of `include` element. We expect, that the attributes of the element represent an existing `.gir` file.
            let dependencies = xml.xpath(
                "/gir:repository/gir:include", 
                namespaces: namespaces, 
                defaultPrefix: "gir"
            )?.lazy.compactMap { node -> GirPackageMetadata.Dependency? in
                guard
                    let name = node.attribute(named: "name"),
                    let version = node.attribute(named: "version")
                else { return nil }
                return GirPackageMetadata.Dependency(name: name, version: version)
            }

            return GirPackageMetadata(
                pkgName: packageName,
                dependency: dependencies.flatMap(Array.init(_:)) ?? []
            )

        }

        throw Error.girParsingFailed
    }
}
