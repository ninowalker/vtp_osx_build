#!/bin/bash -e

FINK=/sw/bin/fink

function fink_package {
    lib=$1
    package=$2
    
    if [ "$package" = "" ]; then
	package=$lib
    fi

    if [ -e /sw/lib/${lib}.dylib -o -e /sw/lib/lib${lib}.dylib ] ; then
	echo "## Found fink package '$package'."
	return 0
    fi
    echo "## Installing fink package '$package'. This requires administrator privileges. You will be prompted for a password."
    $FINK -b install $package
}

# takes a library name and an optional package name.
fink_package $1 $2