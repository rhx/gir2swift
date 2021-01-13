#!/bin/bash

## Function used to determine, whether provided path requires processing by gir2swift
## ARGUMENT 1: Path to the Swift package in question
## RETURN: `true` if package contains dependency to gir2swift and contains file named "gir2swift-manifest.sh" 
function is_processable_arg-path {
    local PACKAGE_PATH=$1

    local CALLER=$PWD
    cd $PACKAGE_PATH

    local PACKAGE=`swift package dump-package`
    local GENERATED=`jq -r '.dependencies | .[] | select(.name == "gir2swift") | .name' <<< $PACKAGE`
    local MANIFEST="gir2swift-manifest.sh"

    if [[ $GENERATED && -f "$MANIFEST" ]]
    then
        cd $CALLER
        return 0
    else
        cd $CALLER 
        return 1
    fi
}

## Function which searches for folder containing all .gir files provided in argument. Exists if no such folder was found. Searched domain is specified in the foor loop of this function.
## ARGUMENT 1: List of gir names without .gir suffixes.
## RETURN: Path to the folder 
function gir_path_arg-gir-names {
    local GIR_NAMES=$1

    local GIR_FILES=`for NAME in ${GIR_NAMES}; do echo -n "${NAME}.gir "; done`

    for DIR in "/usr/local/share/gir-1.0" "/usr/share/gir-1.0" ; do
        CURRENT=$DIR
        for GIR in $GIR_FILES; do
	        if ! [ -f "${DIR}/${GIR}" ] ; then
		        unset CURRENT
	        fi
        done

        if ! [ -z ${CURRENT} ] ; then
            echo "$CURRENT"
            break
        fi
    done

    exit 1
}

## Searches Swift packages provided in the argument for gir2swift package. In case the package is found, the package is built and path to executable is returnes
## ARGUMENT 1: JSON of dependency graph fetched by the root Package.
## RETURN: Path to gir2swift executable
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

## Filters list of dependencies provided in the argument and returns only those which require processing by gir2swift.
## ARGUMENT 1: JSON of dependency graph fetched by the root package.
## ARGUMENT 2: Name of the Swift package which dependencies should be returned.
## RETURN: List of all paths to the Swift packages which should be processed.
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

## Returns names of all GIR files of provided packages.
## ARGUMENT 1: List of paths to the packages in question. ONLY PROCESSABLE PACKAGES ARE VALID INPUT.
## RETURN: List of names of gir files.
function get_gir_names_arg-packages {
    local PACKAGES=$1

    for PACKAGE in $PACKAGES
    do
        bash -c "$PACKAGE/gir2swift-manifest.sh gir-name"
    done 
}

## Returns name of Swift package. This function depends on working directiory it is run in. This function is exported and required by manifests.
function package_name {
    local PACKAGE=`swift package dump-package`
    local NAME=`jq -r '.name' <<< $PACKAGE`

    echo $NAME
}
export -f package_name

## Returns all pkg-config packages required by targets specified in a Swift package. This feature is intended as a support for macOS. This function depend on working directory. This function is exported and required by manifests.
function package_pkg_config_arguments {
    local PACKAGE=`swift package dump-package`
    local NAME=`jq -r '.targets[] | select(.pkgConfig != null) | .pkgConfig?' <<< $PACKAGE`

    echo $NAME
}
export -f package_pkg_config_arguments

## This function name of Swift package on specified path.
## ARGUMENT 1: Path to the package in question.
## RETURN: Name of the package
function package_name_arg-path {
    local PACKAGE_PATH=$1

    local CALLER=$PWD
    cd $PACKAGE_PATH
    
    local PACKAGE=`swift package dump-package`
    local NAME=`jq -r '.name' <<< $PACKAGE`

    cd $CALLER

    echo $NAME
}


# Command
COMMAND=$1

case $COMMAND in
generate) 
    TOP_LEVEL_PACKAGE_PATH=$2
    OPTIONAL_ALTERNATIVE_G2S_PATH=$3

    # Fetch and retain dependency graph, since this operation takes a lot of time.
    cd $TOP_LEVEL_PACKAGE_PATH
    DEPENDENCIES=`swift package show-dependencies --format json`
    PROCESSABLE=$(get_processable_dependencies_arg-deps_arg-name "$DEPENDENCIES" "$(package_name)")

    ALL_PROCESSABLE="$PROCESSABLE"
    if $(is_processable_arg-path "$TOP_LEVEL_PACKAGE_PATH")
    then
        ALL_PROCESSABLE="$TOP_LEVEL_PACKAGE_PATH $PROCESSABLE"
    fi

    # Search for path that contains all GIR files
    ALL_GIR_NAMES=$(get_gir_names_arg-packages "$ALL_PROCESSABLE")
    GIR_PATH=$(gir_path_arg-gir-names "$ALL_GIR_NAMES")
    echo "Girs located at $GIR_PATH"

    # Determine path to gir2swift executable
    if [ -z "$OPTIONAL_ALTERNATIVE_G2S_PATH" ]
    then
        echo "Building gir2swift"
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
	echo -n "Generate Swift Wrapper for "$PACKAGE_NAME"
        bash -c "$PACKAGE/gir2swift-manifest.sh generate \"$PACKAGE\" \"$G2S_PATH\" \"$GIR_NAMES\" \"$GIR_PATH\" "
    done

    if $(is_processable_arg-path "$TOP_LEVEL_PACKAGE_PATH")
    then
        GIR_NAMES=$(get_gir_names_arg-packages "$PROCESSABLE")
        bash -c "$TOP_LEVEL_PACKAGE_PATH/gir2swift-manifest.sh generate \"$TOP_LEVEL_PACKAGE_PATH\" \"$G2S_PATH\" \"$GIR_NAMES\" \"$GIR_PATH\" "
    fi

    ;;
remove-generated) 
    TOP_LEVEL_PACKAGE_PATH=$2

    cd $TOP_LEVEL_PACKAGE_PATH
    DEPENDENCIES=`swift package show-dependencies --format json`
    PROCESSABLE=$(get_processable_dependencies_arg-deps_arg-name "$DEPENDENCIES" "$(package_name)")

    ALL_PROCESSABLE="$PROCESSABLE"
    if $(is_processable_arg-path "$TOP_LEVEL_PACKAGE_PATH")
    then
        ALL_PROCESSABLE="$TOP_LEVEL_PACKAGE_PATH $PROCESSABLE"
    fi

    for PACKAGE in $ALL_PROCESSABLE 
    do
        cd $PACKAGE
        PACK_NAME=$(package_name_arg-path $PACKAGE)
        bash -c "rm Sources/$PACK_NAME/*-*.swift"
    done 
    ;;

c-flags)
    TOP_LEVEL_PACKAGE_PATH=$2

    cd $TOP_LEVEL_PACKAGE_PATH
    DEPENDENCIES=`swift package show-dependencies --format json`
    PROCESSABLE=$(get_processable_dependencies_arg-deps_arg-name "$DEPENDENCIES" "$(package_name)")

    ALL_PROCESSABLE="$PROCESSABLE"
    if $(is_processable_arg-path "$TOP_LEVEL_PACKAGE_PATH")
    then
        ALL_PROCESSABLE="$TOP_LEVEL_PACKAGE_PATH $PROCESSABLE"
    fi

    PKGS=""
    for PACKAGE in $ALL_PROCESSABLE
    do
        cd $PACKAGE
        PKGS="$PKGS $(package_pkg_config_arguments)"
    done

    C=`pkg-config --cflags $PKGS`
    LINKER=`pkg-config --libs $PKGS`

    # Decorating flags returned from pkg-config with -Xcc and -Xlinker flags
    DECORC=`for FLAG in ${C}; do echo -n "-Xcc ${FLAG} "; done`
    DECORL=`for FLAG in ${LINKER}; do echo -n "-Xlinker ${FLAG} "; done`

    # pkg-config on mac generates sequences like "-Wl,-framework,Cocoa" - those sequences are not desirable and refactored into "-framework -Xlinker Cocoa" which with previous decoration results in sequences of "-Xlinker -framework -Xlinker Cocoa"
    MAC_LINKER_FIXES=`echo "${DECORL}" | sed -e 's/ *-Wl, */ /g' -e 's/,/ -Xlinker /g'`    

    echo "${DECORC} ${MAC_LINKER_FIXES}"
    ;;
*)
    echo "Gir 2 swift code generation tool"
    echo "Commands:"
    echo "  generate [path to root package] [optional path to gir2swift executable]"
    echo "  remove-generated [path to root package]"
    echo "  c-flags [path to root package]"
    ;;
esac
