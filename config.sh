#!/bin/sh
#
Mod=gir2swift
if [ -e /usr/lib/libxml2.2.dylib ]; then
	TOOLCHAIN=`xcode-select -p`/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
	if ! [ -e ${TOOLCHAIN} ]; then
		TOOLCHAIN=`xcode-select -p`/SDKs/MacOSX.sdk
	fi
	LINKFLAGS='-Xlinker -lxml2.2'
	CCFLAGS="-Xcc -I${TOOLCHAIN}/usr/include -Xcc -I${TOOLCHAIN}/usr/include/libxml2"
else
	export PKG_CONFIG_PATH=`echo /usr/local/Cellar/libxml2/*/lib/pkgconfig | tr ' ' '\n' | tail -n1`:${PKG_CONFIG_PATH}
	LINKFLAGS=`pkg-config --libs libxml-2.0 | sed -e 's/  */ /g' -e 's/ *$//' | tr ' ' '\n' | sed -e 's/^/-Xlinker /' -e 's/-Wl,//' | tr '\n' ' '`
	CCFLAGS=`pkg-config --cflags libxml-2.0 | sed -e 's/  */ /g' -e 's/ *$//' | tr ' ' '\n' | sed 's/^/-Xcc /' | tr '\n' ' ' `
fi
