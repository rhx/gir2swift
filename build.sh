#!/bin/sh
#
# Wrapper around `swift build' that uses pkg-config in config.sh
# to determine compiler and linker flags
#
. ./config.sh
xmlpkg=`echo Packages/SwiftLibXML-1.*/Package.swift`
[ -e $xmlpkg ] || ./generate-wrapper.sh
exec swift build $CCFLAGS $LINKFLAGS "$@"
