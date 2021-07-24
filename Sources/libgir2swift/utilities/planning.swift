import Foundation
import FoundationNetworking
import Yams
import SwiftLibXML

struct Manifest: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case girName = "gir-name"
        case pkgConfig = "pkg-config"
    }

    let version: UInt
    let girName: String
    let pkgConfig: String
}

struct GirPackageMetadata {
    struct Dependency {
        let name: String
        let version: String

        var girName: String { name + "-" + version }
    }

    let pkgName: String
    let dependency: [Dependency]
}

struct Plan {

    enum Error: Swift.Error {
        case girNotFound(named: String)
        case girParsingFailed
    }

    let girFileToGenerate: URL
    let girFilesToPreload: [URL]
    let pkgConfigName: String

    init(using manifestUrl: URL) throws {
        // From some reason, Data would not provide correct result
        let data = try String.init(contentsOfFile: manifestUrl.path)
        let manifest = try YAMLDecoder().decode(Manifest.self, from: data)
        
        let girPath = try Plan.searchForGir(
            named: manifest.girName, 
            pkgConfig: [manifest.pkgConfig]
        )
        guard let girPath = girPath else {
            throw Error.girNotFound(named: manifest.girName + ".gir" )
        } 

        self.girFileToGenerate = girPath
        self.girFilesToPreload = try Plan.loadPrerequisities(from: girPath, pkgConfig: manifest.pkgConfig)
        self.pkgConfigName = manifest.pkgConfig
    }

    private static func searchForGir(named name: String, pkgConfig: [String]) throws -> URL? {
        let defaultPaths = ["/opt/homebrew/share/gir-1.0", "/usr/local/share/gir-1.0", "/usr/share/gir-1.0"].map { URL.init(fileURLWithPath: $0, isDirectory: false) }

        #if os(macOS)
        let homebrewRelativeGirLocation = "../share/gir-1.0/"
        let homebrewPaths = pkgConfig.compactMap { pkgName -> URL? in 
            let libDir = try? executeAndWait("pkg-config", arguments: ["--variable=libdir", pkgName])
            return libDir.flatMap { 
                let libDirUrl = URL(fileURLWithPath: $0, isDirectory: true)
                return URL(string: homebrewRelativeGirLocation, relativeTo: libDirUrl)
            }
        }

        let searchPaths = homebrewPaths + defaultPaths
        #else
        let searchPaths = defaultPaths
        #endif


        return searchPaths
            .map { $0.appendingPathComponent(name).appendingPathExtension("gir") }
            .first { 
                FileManager.default.fileExists(atPath: $0.path) 
            }
    }

    private static func loadPrerequisities(from gir: URL, pkgConfig: String) throws -> [URL] {
        var explored: [String: URL] = [ gir.deletingLastPathComponent().lastPathComponent : gir ]
        var toExplore: Set<String> = Set(try parsePackageInfo(for: gir).dependency.map(\.girName))

        let pkgConfigCandidates: [String]
        #if os(macOS)
            pkgConfigCandidates = try getAllPkgConfigDependencies(for: pkgConfig)
        #else
            pkgConfigCandidates = []
        #endif

        

        while true {
            if toExplore.isEmpty {
                break
            }

            let executing = toExplore.removeFirst()
            guard let url = try searchForGir(named: executing, pkgConfig: pkgConfigCandidates) else {
                throw Error.girNotFound(named: executing)
            }

            explored[executing] = url

            let packageInfo = try parsePackageInfo(for: url)
            packageInfo.dependency.forEach { dependency in
                if explored[dependency.girName] == nil {
                    toExplore.insert(dependency.girName)
                }
            }
        }

        return Array(explored.values)
    }

    private static func getAllPkgConfigDependencies(for package: String) throws -> [String] {
        var explored: Set<String> = []
        var toExplore: Set<String> = [package]

        while true {
            if toExplore.isEmpty {
                break
            }

            let executing = toExplore.removeFirst()
            explored.insert(executing)

            try getPkgConfigDependencies(for: executing).forEach { result in
                if !explored.contains(result) {
                    toExplore.insert(result)
                }
            }
        }

        return Array(explored)
    }

    private static func getPkgConfigDependencies(for package: String) throws -> [String] {
        guard let output = try executeAndWait("pkg-config", arguments: ["--print-requires", package]) else {
            return []
        }

        let dependecyRecord = output.components(separatedBy: .newlines)
        let packageNames = dependecyRecord.compactMap { line in
            line.components(separatedBy: .whitespaces).first
        }

        return packageNames
    }

    private static func parsePackageInfo(for gir: URL) throws -> GirPackageMetadata {
        guard let xml = XMLDocument(fromFile: gir.path) else {
            throw Error.girNotFound(named: gir.lastPathComponent)
        }

        // @rhx please check this code
        if let repository = xml.first(where: { $0.name == "repository" }) {
            let namespaces = repository.namespaces

            guard 
                let packageName = xml.xpath(
                    "/gir:repository/gir:package", 
                    namespaces: namespaces, 
                    defaultPrefix: "gir"
                )?.first?.attribute(named: "name") 
            else { throw Error.girParsingFailed }

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