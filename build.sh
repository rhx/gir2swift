#!/bin/sh
#
# Wrapper around `swift build' that uses pkg-config in config.sh
# to determine compiler and linker flags
#
. ./config.sh
xmlpkg=`echo "$BUILD_DIR/checkouts/SwiftLibXML.git-*/Package.swift"`
[ -e "$xmlpkg" ] || ./generate-wrapper.sh
exec swift build -c release --build-path "$BUILD_DIR" $CCFLAGS $LINKFLAGS "$@"
