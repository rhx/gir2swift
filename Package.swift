// swift-tools-version:5.2

import PackageDescription

let pkgName = "gir2swift"
let libTarget = "lib\(pkgName)"

let package = Package(
    name: pkgName,
    products: [
        .executable(name: pkgName, targets: [pkgName]),
        .library(name: libTarget, targets: [libTarget]),
    ],
    dependencies: [ .package(url: "https://github.com/rhx/SwiftLibXML.git", .branch("master")) ],
    targets: [
        .target(name: pkgName, dependencies: [.init(stringLiteral: libTarget)]),
        .target(name: libTarget, dependencies: ["SwiftLibXML"]),
        .testTarget(name: "\(pkgName)Tests", dependencies: [.init(stringLiteral: libTarget)]),
    ]
)
