#!/bin/bash -e

# dependencies are generally built into the staging directory, under the PREFIX 
# provided to the dep's configure script. This moves those files into the 
# build.shared/Shared directory
function finish_install {
    cd ${STAGING_DIR}${PREFIX}
    
    echo "# Moving " ${STAGING_DIR}${PREFIX}/* 
    echo "       to ${DEST_DIR}"
    cp -R ${STAGING_DIR}${PREFIX}/* ${DEST_DIR}
    rm -Rf ${STAGING_DIR}${PREFIX}/*
}

# This changes the hardcoded paths binaries and dylibs use to find other dylibs.
function fix_binary_links {
    echo "## Fixing binary links in ${STAGING_DIR}${PREFIX}"
    cd ${STAGING_DIR}${PREFIX}

    for f in `find lib -name "*.dylib" -type f`; do
	map_libpaths $PREFIX/lib @executable_path/../Shared/lib $f
    done
    for f in `find bin -type f`; do
	map_binlibpaths $PREFIX/lib @executable_path/../lib $f
    done
}

# changes install names and such in dynamic libraries.
# for more info, man install_name_tool
function map_libpaths {
    from=$1; shift
    to=$1; shift
    lib=$1; shift
    curr=`dirname $lib`
    lib=`basename $lib`
    cd $curr
    install_name_tool -id ${to}/`basename $lib` $lib
    for l in `otool -L $lib | grep "$from" | perl -pe 's/\(.*\)//; s/\s+/ /;'`; do
	install_name_tool -change $l ${to}/`basename $l` $lib
    done
    cd -
}

# changes dynamic library paths encoded in binary executables
# for more info, man install_name_tool
function map_binlibpaths {
    from=$1; shift
    to=$1; shift
    bin=$1; shift
    curr=`dirname $bin`
    bin=`basename $bin`
    cd $curr
    for l in `otool -L $bin | grep "$from" | perl -pe 's/\(.*\)//; s/\s+/ /;'`; do
	install_name_tool -change $l ${to}/`basename $l` $bin
    done
    cd -
}

STAGING_DIR=$1
PREFIX=$2
DEST_DIR=$3

#fix_binary_links
#finish_install