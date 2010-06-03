#!/bin/bash -e

#### Variables

WORKING=$HOME/vterrain
DOBUILD=1
DOINSTALL=1
DOTEST=0
PYTHON_SUPPORT=0

# TODO implement universal binary support
UNIVERSAL_BINARY=0

# TODO flag for debug vs release; unimplemented
RELEASE=0

# yes, there is a good reason for this.  See fix_binary_links
PREFIX=/VTPSharedLibraries_with_a_very_long_name_for_install_name_changes

# staging is temporary per dependency.  Deps are built into it, "installed" into $BUILD_SHARED_DIR
STAGING_DIR=$WORKING/build.staging
# a directory where all the dependencies are moved into after being built into staging.
BUILD_SHARED_DIR=$WORKING/build.shared/Shared

# the directory where VTP binaries and application data are put.
VTP_BUILD_DIR=$WORKING/build.vtp

# the directory containing all the VTP data, including plant models, etc.
VTP_DATA_DIR=$WORKING/vtp-data

# The OSG target to build; Deployment or Development
OSG_TARGET=Deployment

FINK=/sw/bin/fink
SUDO=sudo

# defines the dependency names and folder
source `dirname $0`/DEPENDENCIES

#### Functions
function display_info {
    echo "
Usage: $0 <options> [ALL|<package name> <...>]
   This scripts handles the building and installation of VTP and its dependencies.
   - Use '$0 ALL' to build and install everything, or
   - Use '$0 <package_name> <...>' to build one or more of the following packages:
      $LMINI
      $GDAL
      $WXMAC
      $MACPYTHON
      $PROJ
      $OSG
    e.g: '$0 gdal libMini'

   - Build VTP with:
      '$0 vtp' for a full build.
      '$0 vtp=<maketarget>' to build a specific target (vtp=clean, for example)

   Options: 
      --working-dir=<dirname>: the directory containing all of the packages. Presently defaults to: $WORKING
      --vtpdata-dir=<dirname>: the directory containing the VTP data directories WorldMap/ and Data/.
      --osgTarget=<Deployment|Development>: allows changing the osg target
      --no-python: disables download of python dependencies. (Default)
      --with-python: enables download of python dependencies.
      --no-build: disable the build/compile parts of the script.
      --no-install: disable the install parts of the script.
      --run-test: runs test portions of the script (currently only for wxPython).
      --help: this message.
"
}

function doinstall {
    test $DOINSTALL -eq 1
    return $?
}

function dobuild {
    test $DOBUILD -eq 1
    return $?
}

function dotest {
    test $DOTEST -eq 1
    return $?
}

function chkerror { 
    if [ $? -ne 0 ]; then
	exit 1 
    fi 
}


# dependencies are generally built into the staging directory, under the PREFIX 
# provided to the dep's configure script. This moves those files into the 
# build.shared/Shared directory
function finish_install {
    cd ${STAGING_DIR}${PREFIX}
    
    echo "# Moving " ${STAGING_DIR}${PREFIX}/* 
    echo "       to ${BUILD_SHARED_DIR}"
    cp -R ${STAGING_DIR}${PREFIX}/* ${BUILD_SHARED_DIR}
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


# Installs fink dependencies
function handle_fink_packages {
    if dobuild || doinstall  ; then
	fink_package libxml2 libxml2
	fink_package netcdf libnetcdf
	fink_package libpng3 libpng.3
	fink_package libjpeg libjpeg
	fink_package libtiff libtiff
	fink_package libwww libwwwcore
	fink_package curl libcurl
	fink_package freetype libttf
    fi
}

function fink_package {
    package=$1
    lib=$2
    if [ -e /sw/lib/${lib}.dylib -o -e /sw/lib/lib${lib}.dylib ] ; then
	echo "## Found fink package '$package'."
	return 0
    fi
    echo "## Installing fink package '$package'. This requires administrator privileges. You will be prompted for a password."
    $FINK -b install $package
}

# Builds and installs (to $BUILD_SHARED_DIR) libMini
function handle_libMini {
    cd $WORKING/$LMINI/mini 

    if dobuild ; then
	echo "## Building libMini in `pwd`"
	./build.sh
    fi

    if doinstall ; then
	echo "## Installing libMini in $BUILD_SHARED_DIR"
	cp -fp libMini.a $BUILD_SHARED_DIR/lib
	cp -fp minibase.h minitime.h miniOGL.h mini.h pnmbase.h pnmsample.h *.h $BUILD_SHARED_DIR/include
    fi
}


# Builds and installs (to $BUILD_SHARED_DIR) gdal
function handle_gdal {
    cd $WORKING/$GDAL/gdal*

    if dobuild ; then
	echo "## Building gdal in `pwd`"
	PYFLAG="--without-python"
	if [ $PYTHON_SUPPORT -eq 1 ] ; then 
	    PYFLAG="--with-python"
	fi
	LDFLAGS=-L/sw/lib CFLAGS=-I/sw/include CXXFLAGS=-I/sw/include \
	    ./configure --prefix=$PREFIX --disable-static \
	    $PYFLAG --with-tiff=/sw --with-png=/sw --with-jpeg=/sw
	
	# hack attack: http://article.gmane.org/gmane.comp.gis.gdal.devel/13803
	perl -i -p -e 's%(\$\(LD\) \$\(LNK_FLAGS\) .*?)\.o %$1.lo %' \
	    apps/GNUmakefile
        # This to build a global framework for /Library/Frameworks, 
        # use --with-macosx-framework, and the prefix wil be ignored.
	# OSX_FRAMEWORK_PREFIX=
	make
    fi
    
    if doinstall ; then
	echo "## Installing gdal"
        # If building a global framework, you must use sudo:
	# sudo make install
	make install DESTDIR=$STAGING_DIR
	fix_binary_links
	finish_install
    fi
}


# Dowloads and installs wxMac
function handle_wxMac {
    if [ $PYTHON_SUPPORT -eq 1 ] ; then
	wdir=$WORKING/$WXPYTHON/wxPython-src-*/
    else
	wdir=$WORKING/$WXMAC/wxMac-2.*/
    fi

    if dobuild ; then
    cd $wdir
    echo "## Building wxMac in `pwd`"
    mkdir -p bld
    cd bld
    flags=""
    if [ $UNIVERSAL_BINARY -eq 1 ] ; then
	flags="$flags --enable-universal_binary"
    fi
    if [ $RELEASE -eq 0 ] ; then
	flags="$flags --disable-debugreport --enable-debug_flag"
    fi

    if [ ! -e Makefile ] ; then
    LDFLAGS=-L/sw/lib CFLAGS=-I/sw/include CXXFLAGS=-I/sw/include \
	../configure --with-mac \
	--prefix=$PREFIX \
        --with-opengl --enable-geometry --enable-graphics_ctx \
        --enable-sound --with-sdl \
        --enable-mediactrl \
        --enable-display \
	--enable-static=no --enable-shared=yes \
	--enable-monolithic  \
	--enable-optimize --enable-unicode $flags
    fi
    make


    if [ $PYTHON_SUPPORT -eq 1 ] ; then
	echo "## Building wx extensions."
	make -C contrib/src/gizmos 
	make -C contrib/src/stc
    fi
    
    fi # dobuild: wx

    # patches the wx-config files with the appropriate --prefix path
    perl -i -p -e "s%${PREFIX}%${BUILD_SHARED_DIR}%" $wdir/bld/lib/wx/config/*


    if doinstall ; then
	cd $wdir/bld
	echo "## Installing wxMac"
	make install DESTDIR=$STAGING_DIR

	if [ $PYTHON_SUPPORT -eq 1 ] ; then
	    make -C contrib/src/gizmos install DESTDIR=$STAGING_DIR
            make -C contrib/src/stc install DESTDIR=$STAGING_DIR
	fi

	# post install cleanup
	cd ${STAGING_DIR}${PREFIX}/bin
	rm wx-config
	ln -s ../lib/wx/config/mac-unicode-*-2.8 wx-config
        fix_binary_links
	finish_install
    fi

    if [ dobuild -a $PYTHON_SUPPORT -eq 1 ] ; then # wxpython
	cd $wdir/wxPython
	echo "## Building python modules in `pwd`"

	flags=""
	if [ $RELEASE -eq 0 ] ; then
	    flags="--debug"
	fi
	python2.4 setup.py build_ext --inplace $flags WX_CONFIG=$BUILD_SHARED_DIR/bin/wx-config MONOLITHIC=1 UNICODE=1 USE_SWIG=0
	PATH="${PREFIX}:${PATH}"
	export PATH
	if [ ! -h /Developer/SDKs/MacOSX10.4u.sdk/sw ]; then 
 	        ## see the tech note here: 
	        ## http://lists.apple.com/archives/darwin-dev/2006/Apr/msg00042.html
	    echo "## ld fails if there isn't a link to /sw in /Developer/SDKs/MacOSX10.4u.sdk"
	    echo "## Creating the link..."
	    sudo ln -s /sw /Developer/SDKs/MacOSX10.4u.sdk/sw
	fi
    fi

    if [ doinstall -a $PYTHON_SUPPORT -eq 1 ] ; then 
	cd $wdir/wxPython
	sudo python2.4 setup.py install
    fi

    # run the demo
    if dotest ; then
	cd $WORKING/$WXPYTHON/wxPython-src-*/wxPython
	echo "## Running wxPython test from `pwd`"
	export DYLD_LIBRARY_PATH=${BUILD_SHARED_DIR}
	export PYTHONPATH=`pwd`
	cd demo
	python2.4 demo.py
    fi

}

function handle_MacPython {
    # as it's a framework, it doesn't make sense to download/install it 
    # if it's already installed
    if [ ! -e /Library/Frameworks/Python.framework/Versions/2.4/bin/python ] ; then
	echo "## It seems you already have a MacPython framework installed."
	return
    fi

    cd $WORKING/$MACPYTHON

    if doinstall ; then
	open $MACPYTHON_ARCHIVE
	sleep 4
	open /Volumes/*Python*/
	echo "#### After installing the package with the GUI, hit enter."
	read
    fi
}


# Builds and installs (to $BUILD_SHARED_DIR) proj.4
function handle_proj {
    cd $WORKING/$PROJ/proj-?.?.?
    
    if dobuild ; then
	echo "## Building proj.4 in `pwd`"
	./configure --prefix=$PREFIX
	make
    fi
    if doinstall ; then 
	echo "## Installing proj"
	make install DESTDIR=$STAGING_DIR
	fix_binary_links
	finish_install
    fi
}

# Builds and installs (to $BUILD_SHARED_DIR) OSG configured for OS X
function handle_osg {
    cd $WORKING/osg/${OSG_ARCHIVE%.*}

    if dobuild ; then
	# if an error is generated in Tessalator.cpp, remove the TRIPLEDOT
	# flag
	cmake -C . -DCMAKE_BUILD_TYPE=Release -DOSG_USE_FLOAT_MATRIX:BOOL=ON \
	    -DBUILD_OSG_APPLICATIONS=OFF -DCMAKE_OSX_ARCHITECTURES=i386 \
	    -DOSG_GLU_TESS_CALLBACK_TRIPLEDOT:BOOL=OFF \
	    -DCMAKE_INSTALL_PREFIX:PATH=$STAGING_DIR${PREFIX}
#	    -DDEFAULT_GLU_TESS_CALLBACK_TRIPLEDOT=OFF \
	make
    fi

    if doinstall ; then
	make install
	fix_binary_links
	finish_install
    fi
}

function handle_quikgrid {
    # quick grid has not been ported to OSX.
    return 0
}

# Flips bits in the config_vtdata.h
# $1: name of the #define
# $2: value
function toggle_vtp_dependency {
    cd $WORKING/vtp/TerrainSDK/vtdata
    SUB_STR="s/\#define $1\s+\d/\#define $1 $2/"
    echo "## Setting $1 to $2: $SUB_STR"
    perl -i -p -e "$SUB_STR" config_vtdata.h
} 

# Builds VTP with make.  This is now defunct, as we just use Xcode,
# but I'm keeping it around for the near future while we transition.
function build_vtp {
    cd $WORKING/vtp/
    
    mkdir -p $VTP_BUILD_DIR
    echo "## Setting up $VTP_BUILD_DIR"
    if [ ! -f $VTP_BUILD_DIR/Enviro.xml ] ; then
	## Expect the VTP Data/ dir next to the *.app files
	perl -p -e "s%<DataPath>../Data/</DataPath>%<DataPath>./Data/</DataPath>%" $WORKING/vtp/TerrainApps/Enviro/Enviro.xml > $VTP_BUILD_DIR/Enviro.xml
    else
	echo "# $VTP_BUILD_DIR/Enviro.xml exists. Will not overwrite."
    fi
    if [ ! -h $VTP_BUILD_DIR/Shared ] ; then
	ln -s $BUILD_SHARED_DIR $VTP_BUILD_DIR/Shared
    fi
    if [ ! -h $VTP_BUILD_DIR/Data ] ; then
	ln -s $VTP_DATA_DIR/Data $VTP_BUILD_DIR/Data
    fi
    if [ ! -h $VTP_BUILD_DIR/WorldMap ] ; then
	ln -s $VTP_DATA_DIR/WorldMap $VTP_BUILD_DIR/WorldMap
    fi

    make $VTP_TARGET \
	OSX_APPS=$VTP_BUILD_DIR \
	FRAMEWORKS="$VTP_BUILD_DIR/Shared/Frameworks" \
	LOCALBASE=$BUILD_SHARED_DIR \
	WX_DIR=$BUILD_SHARED_DIR \
        SWITCHES="-DUNIX -DSUPPORT_QUIKGRID=0 -DSUPPORT_NETCDF=1 -DSUPPORT_HTTP=1 -DSUPPORT_BZIP2=1 -DVTLIB_OSG=1 -DSUPPORT_SQUISH=0 -DSUPPORT_PYTHON=$PYTHON_SUPPORT"
}

# builds VTP with xcode
function handle_vtp {
    open $WORKING/vtp/mac/VTP.xcodeproj
    cd $WORKING/vtp/mac && xcodebuild -configuration Release -target TerrainApps
}

####  "Main"

source `dirname $0`/SETFLAGS

if [ $# -eq 0 ]; then
    display_info
    exit 0
fi

while [ $# -gt 0 ]; do    # Until you run out of parameters . . .
  case "$1" in
      --no-build)
	  DOBUILD=0
	  ;;
      --no-install)
	  DOINSTALL=0
	  ;;
      --run-test)
	  DOTEST=1
	  ;;
      vtp=*)
          VTP_TARGET=${1##*=}
	  VTPF=1
	  ;;
      -h|--help)
	  display_info
	  exit
	  ;;
      --osgTarget=*)
          OSG_TARGET=${1##*=}
	  ;;
      *)
	  if set_flag $1; then
	      # all good
	      true
	  else
	      echo "#### Error: unknown argument $1"
	      display_info
	      exit 1
	  fi
	  ;;
  esac
  shift       # Check next set of parameters.
done


mkdir -p $STAGING_DIR
mkdir -p $BUILD_SHARED_DIR
mkdir -p $BUILD_SHARED_DIR/Frameworks
mkdir -p $BUILD_SHARED_DIR/Plugins
mkdir -p $BUILD_SHARED_DIR/lib
mkdir -p $BUILD_SHARED_DIR/include



if [ $PYTHON_SUPPORT -eq 0 ] ; then
    WXPYTHONF=0
    MACPYTHONF=0
fi


if [ $FINKF -eq 1 ]; then
    handle_fink_packages
fi

if [ $LMINIF -eq 1 ]; then
    handle_libMini
fi

if [ $GDALF -eq 1 ]; then
    handle_gdal
fi

if [ $PROJF -eq 1 ]; then
    handle_proj
fi

if [ $WXMACF -eq 1 ]; then
    handle_wxMac
fi

if [ $MACPYTHONF -eq 1 ]; then
    handle_MacPython
fi

if [ $OSGF -eq 1 ]; then
    handle_osg
fi

if [ $QUIKF -eq 1 ]; then
    handle_quikgrid
fi

if [ $VTPF -eq 1 ]; then
    handle_vtp
fi

exit 0
