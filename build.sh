#!/bin/sh
#
export PATH=/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin:"${PATH}"
export PKG_CONFIG_PATH=`echo /usr/local/Cellar/libxml2/*/lib/pkgconfig | tr ' ' '\n' | tail -n1`:${PKG_CONFIG_PATH}
LINKFLAGS=`pkg-config --libs libxml-2.0 | tr ' ' '\n' | sed 's/^/-Xlinker /' | tr '\n' ' '`
CCFLAGS=`pkg-config --cflags libxml-2.0 | tr ' ' '\n' | sed 's/^/-Xcc /' | tr '\n' ' ' `
swift build $CCFLAGS $LINKFLAGS
