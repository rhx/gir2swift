#!/bin/sh
#
Mod=gir2swift
XML_VER=2.2
MAJOR_VER=2.0
JAZZY_VER=5.2.0
export PATH="${BUILD_DIR}/gir2swift/.build/release:${BUILD_DIR}/gir2swift/.build/debug:${PATH}:/usr/local/opt/ruby/bin:`echo /usr/local/lib/ruby/gems/*/bin | tr ' ' '\n' | tail -n1`:${PATH}:`echo /var/lib/gems/*/gems/jazzy-*/bin/ | tr ' ' '\n' | tail -n1`:/usr/local/bin"
if [ -e /usr/lib/libxml${XML_VER}.dylib ]; then
	TOOLCHAIN=`xcode-select -p`/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
	if ! [ -e ${TOOLCHAIN} ]; then
		TOOLCHAIN=`xcode-select -p`/SDKs/MacOSX.sdk
	fi
	LINKFLAGS="-Xlinker -lxml${XML_VER}"
	CCFLAGS="-Xcc -I${TOOLCHAIN}/usr/include -Xcc -I${TOOLCHAIN}/usr/include/libxml2"
else
	export PKG_CONFIG_PATH=`echo /usr/local/Cellar/libxml2/*/lib/pkgconfig | tr ' ' '\n' | tail -n1`:${PKG_CONFIG_PATH}
	LINKFLAGS=`pkg-config --libs libxml-$MAJOR_VER | sed -e 's/  */ /g' -e 's/ *$//' | tr ' ' '\n' | sed -e 's/^/-Xlinker /' -e 's/-Wl,//' | tr '\n' ' '`
	CCFLAGS=`pkg-config --cflags libxml-$MAJOR_VER | sed -e 's/  */ /g' -e 's/ *$//' | tr ' ' '\n' | sed 's/^/-Xcc /' | tr '\n' ' ' `
fi
