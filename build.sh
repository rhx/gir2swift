#!/bin/sh
#
# Wrapper around `swift build' that uses pkg-config in config.sh
# to determine compiler and linker flags
#
. ./config.sh
xmlpkg=`echo .build/checkouts/SwiftLibXML.git-*/Package.swift`
[ -e $xmlpkg ] || ./generate-wrapper.sh
exec swift build -c release $CCFLAGS $LINKFLAGS "$@"
