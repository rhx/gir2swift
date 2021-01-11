#!/bin/sh
#
# Wrapper around `swift test' using config.sh and checking
# that the swift wrapper code exists
#
. ./config.sh
[ -e Sources/${Module}.swift ] || ./generate-wrapper.sh
exec swift test --build-path "$BUILD_DIR" $CCFLAGS $LINKFLAGS "$@"
