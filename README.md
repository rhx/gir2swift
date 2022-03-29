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
5. Create a script that runs `gir2swift` (see [Usage](#Usage) below) and then builds your project using `swift build`
6. If the build phase fails (more likely than not), add code that patches the generated Swift source files (e.g. using `awk` or `sed`) to correct the errors the compiler complains about

## What is new?

Version 14 automates post-processing using `sed` and `awk`, simplifying build-system integration.

Version 13 uses [swift-argument-parser](https://github.com/apple/swift-argument-parser) instead of `getopt()`.

## Usage

### Synopsis

    gir2swift [-v][-s][-m module_boilerplate.swift]{-p file.gir}[file.gir ...]

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

### `Module.blacklist`
This file contains the symbols (separated by newline) that you want to suppress in your output.  Here you should include all the symbols in the `.gir` file that the Swift compiler cannot import from the relevant C language headers.

### `Module.whitelist`
This file contains the symbols (separated by newline) that would otherwise be suppressed (e.g. because `gir2swift` thinks they are duplicates), but you would like to include in the `gir2swift` output.

### `Module.verbatim`
Normally, `gir2swift` tries to translate constants from C to Swift, as per the definitions in the `.gir` files.  Names of constants listed (and separated by newline) in this file will not be translated.

## Prerequisites

### Swift

To build, you need at least Swift 5.2 (but some Linux distributions have issues and seem to **require at least Swift 5.5**), download from https://swift.org/download/ -- if you are using macOS, make sure you have the command line tools installed as well).  Test that your compiler works using `swift --version`, which should give you something like

	$ swift --version
	Apple Swift version 5.4.2 (swiftlang-1205.0.28.2 clang-1205.0.19.57)
    Target: x86_64-apple-darwin21.0.0

on macOS, or on Linux you should get something like:

	$ swift --version
	Swift version 5.4.2 (swift-5.4.2-RELEASE)
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
	sudo apt install libxml2-dev gobject-introspection libgirepository1.0-dev


##### Fedora

On Fedora, you can use the gtk that comes with the distribution.  Just install with the `dnf` package manager:

	sudo dnf install libxml2-devel gobject-introspection-devel


## Building
Normally, you don't build this package directly, but you embed it into your own project (see 'Embedding' below).  However, you can build and test this module separately to ensure that everything works.  Make sure you have all the prerequisites installed (see above).  After that, you can simply clone this repository and build the command line executable (be patient, this will download all the required dependencies and take a while to compile) using

	git clone https://github.com/rhx/gir2swift.git
	cd gir2swift
	./build.sh

### Xcode

On macOS, you can build the project using Xcode instead.  To do this, you need to create an Xcode project first, then open the project in the Xcode IDE:

	./xcodegen.sh
	open gir2swift.xcodeproj

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
	
this probably means that your Swift toolchain is too old, particularly on Linux (at the time of this writing, some Linux distributions require at least Swift 5.5).  Make sure the latest toolchain is the one that is found when you run the Swift compiler (see above).

  If you get an older version, make sure that the right version of the swift compiler is found first in your `PATH`.  On macOS, use xcode-select to select and install the latest version, e.g.:

	sudo xcode-select -s /Applications/Xcode.app
	xcode-select --install

### Known Issues

 * The new build system scripts do not support directory paths with spaces (e.g. the `My Drive` directory used by Google Drive File Stream).  As a workaround, use the old build scripts, e.g. `./build.sh` instead of `run-gir2swift.sh` and `swift build` to build a package.
 * BUILD_DIR is not suported in the new build system.
