// swift-tools-version:5.4

import PackageDescription

let pkgName = "gir2swift"
let libTarget = "lib\(pkgName)"

let package = Package(
    name: pkgName,
    products: [
        .executable(name: pkgName, targets: [pkgName]),
        .library(name: libTarget, targets: [libTarget]),
    ],
    dependencies: [ 
        .package(url: "https://github.com/rhx/SwiftLibXML.git", .branch("main")),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.0")
    ],
    targets: [
        .target(
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
        .testTarget(name: "\(pkgName)Tests", dependencies: [.init(stringLiteral: libTarget)]),
    ]
)
