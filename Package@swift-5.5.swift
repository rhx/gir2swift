// swift-tools-version:5.5

import PackageDescription

let pkgName = "gir2swift"
let libTarget = "lib\(pkgName)"

let package = Package(
    name: pkgName,
    products: [
        .executable(name: pkgName, targets: [pkgName]),
        .library(name: libTarget, targets: [libTarget]),
        .plugin(name: "Gir2SwiftPlugin", targets: ["Gir2SwiftPlugin"])
    ],
    dependencies: [ 
        .package(url: "https://github.com/rhx/SwiftLibXML.git", .branch("main")),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.0")
    ],
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
                .init(stringLiteral: "SwiftLibXML"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .plugin(
            name: "Gir2SwiftPlugin",
            capability: .buildTool(),
            dependencies: ["gir2swift"]
        ),
        .testTarget(name: "\(pkgName)Tests", dependencies: [.init(stringLiteral: libTarget)]),
    ]
)
