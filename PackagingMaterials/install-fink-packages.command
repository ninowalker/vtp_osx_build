#!/bin/bash -e


FINK=/sw/bin/fink

function handle_fink_packages {
    fink_package libxml2 libxml2
    fink_package netcdf libnetcdf
    fink_package libpng3 libpng.3
    fink_package libjpeg libjpeg
    fink_package libtiff libtiff
    fink_package libwww libwwwcore
    fink_package curl libcurl
    fink_package freetype libttf
}

function fink_package {
    package=$1
    lib=$2
    if [ -e /sw/lib/${lib}.dylib -o -e /sw/lib/lib${lib}.dylib ] ; then
	echo " Found fink package '$package' installed already."
	return 0
    fi
    echo "## Installing fink package '$package'. This requires administrator privileges. You will be prompted for a password."
    $FINK -b install $package
}

echo
echo "This script will install VTP's required libraries via fink."
echo 
handle_fink_packages
echo "
Installation of fink packages complete.
"