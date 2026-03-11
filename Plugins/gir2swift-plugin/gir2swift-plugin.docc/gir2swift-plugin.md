# gir2swift-plugin

A SwiftPM build tool plugin that runs `gir2swift` automatically during `swift build`.

## Overview

`gir2swift-plugin` integrates `gir2swift` into the Swift Package Manager build system as a build tool plugin. When a target declares the plugin, SwiftPM calls the plugin's `createBuildCommands` method before compiling Swift sources. The plugin:

1. Locates the `gir2swift-manifest.yaml` for the target (target-local file takes precedence over the package-level file).
2. Reads the primary GIR name from the manifest.
3. Scans the standard GIR installation paths to find a directory that contains the primary GIR file and all prerequisite GIR files discovered from the target's dependency graph.
4. Declares all relevant input files (GIR files, manifest, and target-local configuration files) so SwiftPM can track changes and re-run the command when any input changes.
5. Predicts the set of output files (one Swift file per alphabetical bucket plus the fixed-suffix files).
6. Returns a single build command that invokes `gir2swift`.

### Adding the plugin to your package

```swift
// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MyPackage",
    dependencies: [
        .package(url: "https://github.com/rhx/gir2swift.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "MyLibraryTarget",
            plugins: [
                .plugin(name: "gir2swift-plugin", package: "gir2swift"),
            ]
        ),
    ]
)
```

Your target directory (or the package root) must contain a `gir2swift-manifest.yaml`, for example:

```yaml
version: 1
gir-name: GLib-2.0
pkg-config: glib-2.0
output-directory: Sources/GLib
alpha-names: true
```

### GIR search paths

The plugin checks the following directories in order and uses the first one that contains every required GIR file:

1. `/opt/homebrew/share/gir-1.0` (Homebrew on Apple Silicon)
2. `/usr/local/share/gir-1.0` (Homebrew on Intel or manual installs)
3. `/usr/share/gir-1.0` (Linux system packages)

### Error handling

Discovery failures throw descriptive errors:

- `failedToGetGirNameFromManifest` — the manifest does not declare a GIR name.
- `failedToGetGirDirectory(containing:)` — no single directory contains all required GIR files.

## Topics

### Related

- <doc://gir2swift/documentation/gir2swift>
- <doc://libgir2swift/documentation/libgir2swift>
