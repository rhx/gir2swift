# gir2swift
A simple GIR parser in Swift for creating Swift types for a .gir file

## Prerequisites

### Swift

To build, you need at least Swift 4.2 (Swift 5.x should work fine), download from https://swift.org/download/ -- if you are using macOS, make sure you have the command line tools installed as well).  Test that your compiler works using `swift --version`, which should give you something like

	$ swift --version
	Apple Swift version 5.0.1 (swiftlang-1001.0.82.4 clang-1001.0.46.5)
	Target: x86_64-apple-darwin18.6.0

on macOS, or on Linux you should get something like:

	$ swift --version
	Swift version 5.0.1 (swift-5.0.1-RELEASE)
	Target: x86_64-unknown-linux-gnu

### LibXML 2.9.4 or higher

These Swift wrappers have been tested with libxml-2.9.4 and 2.9.9.  They should work with higher versions, but YMMV.  Also make sure you have `gobject-introspection` and its `.gir` files installed.

#### macOS

On current versions of macOS, you need to install `libxml2` using HomeBrew (the version that comes with the system does not include the necessary development headers -- for HomeBrew setup instructions, see http://brew.sh):

	brew update
	brew install libxml2 gobject-introspection


#### Linux

##### Ubuntu

On Ubuntu 16.04 and 18.04, you can use the gtk that comes with the distribution.  Just install with the `apt` package manager:

	sudo apt update
	sudo apt install libxml2-dev gobject-introspection libgirepository1.0-dev


##### Fedora

On Fedora 29, you can use the gtk that comes with the distribution.  Just install with the `dnf` package manager:

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

### Old Swift toolchain or Xcode
If you get an error such as

	$ ./build.sh 
	error: unable to invoke subcommand: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-package (No such file or directory)
	
this probably means that your Swift toolchain is too old.  Make sure the latest toolchain (Swift 5.0.1 at the time of this writing) is the one that is found when you run the Swift compiler (see above).

  If you get an older version, make sure that the right version of the swift compiler is found first in your `PATH`.  On macOS, use xcode-select to select and install the latest version, e.g.:

	sudo xcode-select -s /Applications/Xcode.app
	xcode-select --install

