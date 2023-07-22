# gir2swift
A simple GIR parser in Swift for creating Swift types for a .gir file

![macOS 11 build](https://github.com/rhx/gir2swift/workflows/macOS%2011/badge.svg)
![macOS 10.15 build](https://github.com/rhx/gir2swift/workflows/macOS%2010.15/badge.svg)
![Ubuntu 20.04 build](https://github.com/rhx/gir2swift/workflows/Ubuntu%2020.04/badge.svg)
![Ubuntu 18.04 build](https://github.com/rhx/gir2swift/workflows/Ubuntu%2018.04/badge.svg)
![gtk macOS](https://github.com/rhx/gir2swift/workflows/gtk%20macOS/badge.svg)
![gtk Ubuntu](https://github.com/rhx/gir2swift/workflows/gtk%20Ubuntu/badge.svg)

## Getting Started
To start a project that uses Swift wrappers around low-level libraries that utilise gobject-introspection, you need to create some scripts that use `gir2swift` to convert the information within gobject-introspection XML (`.gir`) files into Swift.  Here is a brief overview of the basic steps:

1. Install the prerequisites on your system (see [Prerequisites](#Prerequisites) below)
2. Compile `gir2swift` (see [Building](#Building) below)
3. Create a [Swift Package Manager](https://swift.org/package-manager/) module that contains a system target for your underlying low-level library and a library target for the Swift Wrapper library that you want to build
4. Create the necessary Module files (see [Module Files](#Module-Files) below)
5. Add `gir2swift` as a plugin to your `Package.swift` file (see [Usage](#Usage) below)
6. Build your project using `swift build`
6. If the build phase fails (more likely than not), add code that patches the generated Swift source files (e.g. using `awk` or `sed` [Module Files](#Module-Files) -- see blelow) to correct the errors the compiler complains about

## What is new?

Version 16 provides metadata properties and typed generics for collection types such as Lists and Arrays.

Version 15 provides a Package Manager Plugin.  This requires Swift 5.6 or higher
(older versions can be used via the [swift52](https://github.com/rhx/gir2swift/tree/swift52) branch).

## Usage

Normally, you don't build this package directly (but for testing you can - see 'Building' below). Instead you can embed `gir2swift` into your own project using the [Swift Package Manager](https://swift.org/package-manager/).  After installing the prerequisites (see 'Prerequisites' below), add `gir2swift` as a dependency and plugin to your `Package.swift` file.  Here is an example.

### Swift Package Manager plugin

```Swift
// swift-tools-version:5.6

import PackageDescription

let package = Package(name: "MyPackage",
    dependencies: [
        .package(url: "https://github.com/rhx/gir2swift.git", branch: "main"),
    ],    
    targets: [
        .target(
            name: "MyPackage",
            dependencies: [
                .product(name: "gir2swift", package: "gir2swift"),
            ],
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"], .when(configuration: .release)),
                .unsafeFlags(["-suppress-warnings", "-Xfrontend", "-serialize-debugging-options"], .when(configuration: .debug)),
            ],
            plugins: [
                .plugin(name: "gir2swift-plugin", package: "gir2swift")
            ]
        )
    ]
)
```

For this to work, your package needs a `gir2swift-manifest.yaml` (either in the same directory that contains `Package.swift`, or in the `Sources` subdirectory for the relevant targets.  The manifest needs to contain the name (without extension) of the `.gir` and `pkg-config` files to use, e.g.:
```
version: 1
gir-name: GLib-2.0
pkg-config: glib-2.0
output-directory: Sources/GLib
alpha-names: true
```

### Synopsis

    gir2-swift [<options>] [<gir-files> ...]

#### Arguments
```
  <gir-files>             The .gir metadata files to process. Gir files
                          specified in CLI are merged with those specified in
                          the manifest.
```
#### Options
```
  -v                      Produce verbose output.
  -a                      Disables all filters. Wrappers for all C types will
                          be generated.
  --alpha-names           Create a fixed set of output files ending in A-Z.
  -e, --extension-namespace <extension-namespace>
                          Add a namespace extension with the given name.
  -n, --namespace <namespace>
                          Add a namespace with the given name.
  -s                      Create a single .swift file per class.
  --post-process <post-process>
                          Additional files to post-process.
  -p <p>                  Add pre-requisite .gir files to ensure the types in
                          file.gir are known. Prerequisities specified in CLI
                          are merged with the prerequisites found by gir2swift.
  -o <o>                  Specify the output directory to put the generated
                          files into.
  -t, --target-directory <target-directory>
                          Specify the target source directory to read the
                          manifest and configurations from.
  -w, --working-directory <working-directory>
                          Specify the working directory (package directory of
                          the target) to change into.
  --pkg-config-name <pkg-config-name>
                          Library name to pass to pkg-config. Pkg config name
                          specified in CLI trumps the one found in manifest.
  -m <m>                  Add the given .swift file as the main (hand-crafted)
                          Swift file for your library target.
  --manifest <manifest>   Custom path to manifest. (default:
                          gir2swift-manifest.yaml)
  --opaque-declarations   Skips all other generation steps and prints opaque
                          struct stylized declarations for each record and
                          class to stdout.
  -h, --help              Show help information.
```
### Description
`gir2swift` takes the information from a gobject-introspection XML (`file.gir`) file and creates corresponding Swift wrappers.  When reading the `.gir` file, `gir2swift` also reads a number of [Module Files](#Module-Files) that you create with additional information.

The following options are available:

> `-m Module.swift` Add `Module.swift` as the main (hand-crafted) Swift file for your library target.

> `-o directory` Specify the output directory to put the generated files into.

> `-p pre.gir` Add `pre.gir` as a pre-requisite `.gir` file to ensure the types in `file.gir` are known

> `-s` Create a single `.swift` file per class

> `-v` Produce verbose output.

### Examples
The following command generates a Swift Wrapper in `Sources/GIO` from the information in `/usr/share/gir-1.0/Gio-2.0.gir`, copying the content from `Gio-2.0.module` and taking into account information in `GLib-2.0.gir` and `GObject-2.0.gir`:

```
	gir2swift -o Sources/GIO -m Gio-2.0.module -p /usr/share/gir-1.0/GLib-2.0.gir -p /usr/share/gir-1.0/GObject-2.0.gir /usr/share/gir-1.0/Gio-2.0.gir
```

The `Gio-2.0.module` file would need to contain the code that you would want to manually add to your Swift module, for example:

```Swift
import CGLib
import GLib
import GLibObject

public struct GDatagramBased {}
public struct GUnixConnectionPrivate {}
public struct GUnixCredentialsMessagePrivate {}
public struct GUnixFDListPrivate {}
public struct GUnixFDMessagePrivate {}
public struct GUnixInputStreamPrivate {}
public struct GUnixOutputStreamPrivate {}
public struct GUnixSocketAddressPrivate {}

func g_io_module_load(_ module: UnsafeMutablePointer<GIOModule>) {
    fatalError("private g_io_module_load called")
}

func g_io_module_unload(_ module: UnsafeMutablePointer<GIOModule>) {
    fatalError("private g_io_module_unload called")
}
```

Also you would need a corresponding preamble file `Gio-2.0.preamble` that imports the necessary low-level libraries, e.g.:
```Swift
import CGLib
import GLib
import GLibObject
```

## Module Files

In addition to reading a given `Module.gir` file, `gir2swift` also reads a number of module files from the current working directory that contain additional information.  These module files need to have the same name as the `.gir` file, but have a different file extension:

### `Module.preamble`
This file contains the Swift code that you need to as the preamble for every generated `.swift` file (e.g. the `import` statements for all the modules you want to import).

### `Module.module`
This file contains Swift code (in addition to `Module.preamble`) goes into the generated `Module.swift` file (e.g. additional `import` statements or definitions).

### `Module.exclude`
This file contains the symbols (separated by newline) that you want to suppress in your output.  Here you should include all the symbols in the `.gir` file that the Swift compiler cannot import from the relevant C language headers.

### `Module.include`
This file contains the symbols (separated by newline) that would otherwise be suppressed (e.g. because `gir2swift` thinks they are duplicates), but you would like to include in the `gir2swift` output.

### `Module.verbatim`
Normally, `gir2swift` tries to translate constants from C to Swift, as per the definitions in the `.gir` files.  Names of constants listed (and separated by newline) in this file will not be translated.

### `Module.callbackSuffixes`
This file contains the type suffixes that are treated as C callbacks and will be annotated as `@escaping` by `gir2swift`.
Defaults to `["Notify", "Func", "Marshaller", "Callback"]` if not specified.

### `Module.namespaceReplacements`
This file contains `\t`-separated lines containing a namespace and its replacement.  This can be used to work around limitations of the Swift compiler, for example to distinguish between a module and a type that have the same name.

### `Module.sed`
A [sed](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/sed.html) script for post-processing generated files.

### `Module.awk`
An [awk](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/awk.html) script for post-processing generated files.

## Prerequisites

### Swift

To build, you need at least Swift 5.6; download from https://swift.org/download/ -- if you are using macOS, make sure you have the command line tools installed as well).  Test that your compiler works using `swift --version`, which should give you something like

	$ swift --version
	swift-driver version: 1.75.2 Apple Swift version 5.8 (swiftlang-5.8.0.124.2 clang-1403.0.22.11.100)
    Target: arm64-apple-macosx13.0

on macOS, or on Linux you should get something like:

	$ swift --version
	Swift version 5.8.1 (swift-5.8.1-RELEASE)
	Target: x86_64-unknown-linux-gnu

### LibXML 2.9.4 or higher

These Swift wrappers have been tested with libxml-2.9.4 and 2.9.9.  They should work with higher versions, but YMMV.  Also make sure you have `gobject-introspection` and its `.gir` files installed.

#### macOS

On current versions of macOS, you need to install `libxml2` using HomeBrew (the version that comes with the system does not include the necessary development headers -- for HomeBrew setup instructions, see http://brew.sh):

	brew update
	brew install libxml2 gobject-introspection


#### Linux

##### Ubuntu

On Ubuntu 16.04, 18.04 and 20.04, you can use the gtk that comes with the distribution.  Just install with the `apt` package manager:

	sudo apt update
	sudo apt install libxml2-dev gobject-introspection libgirepository1.0-dev jq


##### Fedora

On Fedora, you can use the gtk that comes with the distribution.  Just install with the `dnf` package manager:

	sudo dnf install libxml2-devel gobject-introspection-devel jq


## Building

Normally, you don't build this package directly, but you embed it into your own project (see 'Embedding' below).  However, you can build and test this module separately to ensure that everything works.  Make sure you have all the prerequisites installed (see above).  After that, you can simply clone this repository and build the command line executable (be patient, this will download all the required dependencies and take a while to compile) using

	git clone https://github.com/rhx/gir2swift.git
	cd gir2swift
	swift build

### Xcode

On macOS, you can build the project using Xcode instead.  To do this, simply open the package in the Xcode IDE:

	cd gir2swift
	open Package.swift

After that, use the (usual) Build and Test buttons to build/test this package.


## Troubleshooting
Here are some common errors you might encounter and how to fix them.

### Missing `.gir` Files
If you get an error such as

	Girs located at
	Cannot open '/GLib-2.0.gir': No such file or directory

Make sure that you have the relevant `gobject-introspection` packages installed (as per the Pre-requisites section), including their `.gir` and `.pc` files.

### Old Swift toolchain or Xcode
If, when you run `swift build`, you get a `Segmentation fault (core dumped)` or circular dependency error such as

	warning: circular dependency detected while parsing pangocairo: harfbuzz -> freetype2 -> harfbuzz
	
this probably means that your Swift toolchain is too old.  Make sure the latest toolchain is the one that is found when you run the Swift compiler (see above).

  If you get an older version, make sure that the right version of the swift compiler is found first in your `PATH`.  On macOS, use xcode-select to select and install the latest version, e.g.:

	sudo xcode-select -s /Applications/Xcode.app
	xcode-select --install
