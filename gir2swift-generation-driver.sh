#!/bin/bash

function is_processable_arg-path {
    local PACKAGE_PATH=$1

    local CALLER=$PWD
    cd $PACKAGE_PATH

    local PACKAGE=`swift package dump-package`
    local GENERATED=`jq -r '.dependencies | .[] | select(.name == "gir2swift") | .name' <<< $PACKAGE`

    cd $CALLER

    if [ $GENERATED ]
    then
        return 0
    else 
        return 1
    fi
}

function gir_path {
    # TODO: Add code to determine path

    echo "/usr/share/gir-1.0"
}

function gir_2_swift_executable_arg-deps {
    local DEPENDENCIES=$1

    local G2S_PACKAGE_PATH=`jq -r 'first(recurse(.dependencies[]) | select(.name == "gir2swift")) | .path' <<< $DEPENDENCIES`

    local CALLER=$PWD
    cd $G2S_PACKAGE_PATH

    ./distclean.sh > /dev/null
    ./build.sh > /dev/null

    cd $CALLER

    echo "${G2S_PACKAGE_PATH}/.build/release/gir2swift"
}

function get_processable_dependencies_arg-deps_arg-name {
    local DEPENDENCIES=$1
    local PACKAGE_NAME=$2

    local PACKAGE=`jq -r "first(recurse(.dependencies[]) | select(.name == \"$PACKAGE_NAME\"))" <<< $DEPENDENCIES`

    local ALL_DEPS=`jq -r "recurse(.dependencies[]) | select(.name != \"$PACKAGE_NAME\") | .path" <<< $PACKAGE | sort | uniq`

    for DEP in $ALL_DEPS
    do
        if $(is_processable_arg-path $DEP)
        then
            echo $DEP
        fi
    done
}

function get_gir_names_arg-packages {
    local PACKAGES=$1

    for PACKAGE in $PACKAGES
    do
        bash -c "$PACKAGE/gir2swift-manifest.sh gir-name"
    done 
}

function package_name {
    local PACKAGE=`swift package dump-package`
    local NAME=`jq -r '.name' <<< $PACKAGE`

    echo $NAME
}
export -f package_name

function package_pkg_config_arguments {
    local PACKAGE=`swift package dump-package`
    local NAME=`jq -r '.targets[] | select(.pkgConfig != null) | .pkgConfig?' <<< $PACKAGE`

    echo $NAME
}
export -f package_pkg_config_arguments

function package_name_arg-path {
    local PACKAGE_PATH=$1

    local CALLER=$PWD
    cd $PACKAGE_PATH
    
    local PACKAGE=`swift package dump-package`
    local NAME=`jq -r '.name' <<< $PACKAGE`

    cd $CALLER

    echo $NAME
}


# Building process
TOP_LEVEL_PACKAGE_PATH=$1
OPTIONAL_ALTERNATIVE_G2S_PATH=$2

cd $TOP_LEVEL_PACKAGE_PATH
DEPENDENCIES=`swift package show-dependencies --format json`
GIR_PATH=$(gir_path)
PROCESSABLE=$(get_processable_dependencies_arg-deps_arg-name "$DEPENDENCIES" "$(package_name)")
if [ -z "$OPTIONAL_ALTERNATIVE_G2S_PATH" ]
then
    G2S_PATH=$(gir_2_swift_executable_arg-deps "$DEPENDENCIES")
else
    G2S_PATH=$OPTIONAL_ALTERNATIVE_G2S_PATH
    echo "Using custom gir2swift executable at: $G2S_PATH"
fi

for PACKAGE in $PROCESSABLE
do
    PACKAGE_NAME=$(package_name_arg-path "$PACKAGE")
    PACKAGE_DEPS=$(get_processable_dependencies_arg-deps_arg-name "$DEPENDENCIES" "$PACKAGE_NAME")
    GIR_NAMES=$(get_gir_names_arg-packages "$PACKAGE_DEPS")
    bash -c "$PACKAGE/gir2swift-manifest.sh generate \"$PACKAGE\" \"$G2S_PATH\" \"$GIR_NAMES\" \"$GIR_PATH\" "
done

if $(is_processable_arg-path "$TOP_LEVEL_PACKAGE_PATH")
then
    GIR_NAMES=$(get_gir_names_arg-packages "$PROCESSABLE")
    bash -c "$TOP_LEVEL_PACKAGE_PATH/gir2swift-manifest.sh generate \"$TOP_LEVEL_PACKAGE_PATH\" \"$G2S_PATH\" \"$GIR_NAMES\" \"$GIR_PATH\" "
fi

