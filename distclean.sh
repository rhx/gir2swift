#!/bin/sh
#
# Remove Packages directory and generated files
#
. ./config.sh
./clean.sh
exec rm -rf Package.resolved Package.pins Packages .swiftpm Sources/${Module}.swift Sources/Swift${Mod}.swift ${Mod}.xcodeproj
