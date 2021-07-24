import Foundation
import Yams

struct Manifest: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case girName = "gir-name"
        case pkgConfig = "pkg-config"
    }

    let version: UInt
    let girName: String
    let pkgConfig: String?
}

struct Plan {

    enum Error: Swift.Error {
        case girNotFound, girPrerequisityNotFound(named: String)
    }

    let girFileToGenerate: URL
    let girFilesToPreload: [URL]
    let pkgConfigName: String?

    init(using manifest: URL) throws {
        let data = try Data.init(contentsOf: manifest)
        let manifest = try YAMLDecoder().decode(Manifest.self, from: data)
        
        let girPath = try Plan.searchForGir(
            named: manifest.girName, 
            pkgConfig: manifest.pkgConfig.flatMap {[$0]} ?? []
        )
        guard let girPath = girPath else {
            throw Error.girNotFound
        } 

        self.girFileToGenerate = girPath
        self.girFilesToPreload = try Plan.loadPrerequisities(from: girPath)
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
            .map { $0.appendingPathComponent(name).appendingPathExtension(".gir") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func loadPrerequisities(from gir: URL) throws -> [URL] {

        return []
    }
}