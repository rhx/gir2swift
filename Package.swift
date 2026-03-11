// swift-tools-version:5.6

import PackageDescription

let pkgName = "gir2swift"
let libTarget = "lib\(pkgName)"
let plugin = "\(pkgName)-plugin"

// On Windows, SPM refuses to build packages that use `unsafeFlags` when fetched
// as a remote dependency.  SwiftLibXML requires unsafeFlags on Windows (because
// SPM's systemLibrary/pkgConfig mechanism does not interoperate with MSYS2's
// pkgconf), so it must be referenced as a local (path-based) dependency there.
// On macOS and Linux the normal remote URL is used.
#if os(Windows)
var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/jpsim/Yams.git", from: "4.0.6"),
    .package(path: "../SwiftLibXML"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.1"),
]
#else
var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/jpsim/Yams.git", from: "4.0.6"),
    .package(url: "https://github.com/rhx/SwiftLibXML.git", branch: "main"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.1"),
]
#endif

#if compiler(>=6.2)
packageDependencies.append(
    .package(url: "https://github.com/mipalgu/swift-docc-static", branch: "main")
)
#endif

let package = Package(
    name: pkgName,
    products: [
        .executable(name: pkgName, targets: [pkgName]),
        .library(name: libTarget, targets: [libTarget]),
        .plugin(name: plugin, targets: [plugin]),
    ],
    dependencies: packageDependencies,
    targets: [
        .executableTarget(
            name: pkgName, 
            dependencies: [
                .init(stringLiteral: libTarget)
            ]
        ),
        .target(
            name: libTarget,
            dependencies: [
                "SwiftLibXML",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "Yams"
            ]
        ),
        .testTarget(name: "\(pkgName)Tests", dependencies: [.init(stringLiteral: libTarget)]),
        .plugin(name: plugin,
                capability: .buildTool(),
                dependencies: [.init(stringLiteral: pkgName)]),
    ]
)
