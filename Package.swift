import PackageDescription

let package = Package(
    name: "gir2swift",
    dependencies: [
        .Package(url: "https://github.com/rhx/SwiftLibXML.git", majorVersion: 1, minor: 1)
    ]
)
