#!/bin/sh
#
# Wrapper around `swift build' that uses pkg-config in config.sh
# to determine compiler and linker flags
#
. ./config.sh
xmlpkg=`echo .build/checkouts/SwiftLibXML.git-*/Package.swift`
[ -e $xmlpkg ] || ./generate-wrapper.sh
if [ -z "$@" ]; then
    JAZZY_ARGS="--theme fullwidth --author Ren&eacute;&nbsp;Hexel --author_url https://www.ict.griffith.edu.au/~rhexel/ --github_url https://github.com/rhx/$Mod --github-file-prefix https://github.com/rhx/$Mod/tree/main --root-url http://rhx.github.io/$Mod/ --output docs"
fi
rm -rf .docs.old
mv docs .docs.old 2>/dev/null
sourcekitten doc --spm-module $Mod -- $CCFLAGS $LINKFLAGS |		\
	sed -e 's/^}\]/},/' > .build/$Mod-doc.json
sourcekitten doc --spm-module lib$Mod -- $CCFLAGS $LINKFLAGS |		\
	sed -e 's/^\[//' >> .build/$Mod-doc.json
jazzy --sourcekitten-sourcefile .build/$Mod-doc.json --clean		\
      --module-version $JAZZY_VER --module $Mod $JAZZY_ARGS "$@"
