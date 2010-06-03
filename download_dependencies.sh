#!/bin/bash -e

#### Variables

WORKING=$HOME/vterrain
DOUNPACK=1
DOCLEAN=0

SVN=/sw/bin/svn

source `dirname $0`/DEPENDENCIES

#### Functions
function display_info {
    echo "
Usage: $0 <options> [ALL|<package name> <...>]
   This script downloads VTP dependencies and source code.
   - Use '$0 ALL' to download everything, or
   - Use '$0 <package_name> <...>' to download one or more of the following packages:
      $LMINI
      $GDAL
      $WXMAC
      $WXPYTHON
      $MACPYTHON
      $PROJ
      $QUIKGRID
      $OSG
      $VTP
      $VTP_DATA

   - e.g: '$0 gdal libmini'

   Options: 
      --working-dir=<dirname>: the directory to download the packages to. Presently defaults to: $WORKING
      --vtp-tag=<VTP cvs tag>: checks out a specific version of VTP. Defaults to HEAD.
      --no-python: disables download of python dependencies (default).
      --with-python: enables download of python dependencies.
      --no-unpack: download only. 
      --clean: removes the package and downloads a fresh one.
"
}

function chkerror { 
    if [ $? -ne 0 ]; then
	exit 1 
    fi 
}

# $1: package name
# $2: website
# $3: archive
function fetch_package {
    if [ $DOCLEAN -eq 1 ]; then
	rm -rf $WORKING/$1
    fi

    mkdir -p $WORKING/$1
    cd $WORKING/$1
    if [ ! -e "$3" ]; then
	echo "## Downloading $3 from $2 in $WORKING/$1"
	echo curl -o $3 $2/$3
	curl -o $3 $2/$3
	if [ $? -ne 0 ]; then
	    echo "#### Error downloading $3 from $2/$3.

   Aborting! 

The file location may have been changed on the server. You may be able 
to fix this manually by looking in the DEPENDENCIES file in this directory 
and manually correcting the url information with info from the associated 
website.

Please report the error to nino.walker@gmail.com."
	    rm $3
	    exit 1
	fi
    fi
    if [  $DOUNPACK -eq 1 ]; then
    if [ "${3##*.}" = "zip" ]; then
	echo "## Unzipping $3 (overwriting old files)"
	unzip -q -o $3
    fi
    if [ "${3##*.}" = "gz" ]; then
	# assume its at tar.gz
	echo "## Decompressing $3 (overwriting old files)"
	gunzip -cd $3 | tar xf -
    fi
    if [ "${3##*.}" = "bz2" ]; then
	# assume its at tar.bz2
	echo "## Decompressing $3 (overwriting old files)"
	bzip2 -cd $3 | tar xf -
    fi
    fi
}

# Downloads VTP source from either the archive or CVS
function fetch_vtp_source {
    echo "## Creating $VTP_INSTALL_DIR and setting ownership"
    mkdir -p $WORKING
    cd $WORKING
    echo "## Checking out VTP from SVN repository."
    if [ ! -e "$SVN" ]; then
		"## ERROR: could not find $SVN.  Do you have SVN installed elsewhere? If so, modify the value at the beginning of this script."
		exit
    fi

    if [ "x$VTP_BRANCH_TAG" = "x" ]; then
		$SVN checkout http://vtp.googlecode.com/svn/trunk/ vtp  
    else
		echo "## WARNING: Untested branch tag feature with SVN. Bailing."
		exit
		$SVN checkout http://vtp.googlecode.com/svn/ -r $VTP_BRANCH_TAG vtp  
    fi
}

####  "Main"

source `dirname $0`/SETFLAGS

VTPF=0

if [ $# -eq 0 ]; then
    display_info
    exit 0
fi

while [ $# -gt 0 ]; do    # Until you run out of parameters . . .
  case "$1" in
      --clean)
	  DOCLEAN=1
	  ;;
      --no-unpack)
	  DOUNPACK=0
	  ;;
     --vtp-tag=*)
          VTP_BRANCH_TAG=${1##*=}
	  ;;
      vtp-data)
	  VTP_DATAF=1
	  ;;
      --help | -h)
	  display_info
	  exit
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

# check if python will be supported
if [ $PYTHON_SUPPORT -eq 0 ] ; then
    WXPYTHONF=0
    MACPYTHONF=0
fi

if [ $PYTHON_SUPPORT -eq 1 -a $WXMACF -eq 1 ] ; then
    WXMACF=0
    WXPYTHONF=1
fi

if [ $LMINIF -eq 1 ]; then
    #fetch_package $LMINI $LMINI_DL_SITE $LMINI_ARCHIVE
    rm -rf $WORKING/libMini
    mkdir -p $WORKING/libMini
    cd $WORKING/libMini
    svn co -r $LMINI_REV http://libmini.googlecode.com/svn/libmini/mini mini
fi

if [ $GDALF -eq 1 ]; then
    fetch_package $GDAL $GDAL_DL_SITE $GDAL_ARCHIVE
fi

if [ $PROJF -eq 1 ]; then
    fetch_package $PROJ $PROJ_DL_SITE $PROJ_ARCHIVE
fi

if [ $WXMACF -eq 1 ]; then
    fetch_package $WXMAC $WXMAC_DL_SITE $WXMAC_ARCHIVE
fi

if [ $WXPYTHONF -eq 1 ]; then
    fetch_package $WXPYTHON $WXPYTHON_DL_SITE $WXPYTHON_ARCHIVE
fi

if [ $MACPYTHONF -eq 1 ]; then
    fetch_package $MACPYTHON $MACPYTHON_DL_SITE $MACPYTHON_ARCHIVE
fi

if [ $OSGF -eq 1 ]; then
    fetch_package $OSG $OSG_DL_SITE $OSG_ARCHIVE
fi

if [ $QUIKF -eq 1 ]; then
    fetch_package $QUIKGRID $QUIKGRID_DL_SITE $QUIKGRID_ARCHIVE
fi

if [ $VTP_DATAF -eq 1 ] ; then
    fetch_package $VTP_DATA $VTP_DATA_DL_SITE $VTP_DATA_ARCHIVE
    fetch_package $VTP_DATA $VTP_DATA_DL_SITE $VTP_DATA_DEMO_ARCHIVE
    fetch_package $VTP_DATA $VTP_DATA_DL_SITE $VTP_DATA_PLANT_ARCHIVE
    rm -rf $WORKING/$VTP_DATA/{Data,WorldMap}
    mv -f $WORKING/$VTP_DATA/VTP/TerrainApps/Data $WORKING/$VTP_DATA/
    mv -f $WORKING/$VTP_DATA/VTP/TerrainApps/VTBuilder/WorldMap $WORKING/$VTP_DATA/
    mv -f $WORKING/$VTP_DATA/PlantModels/* $WORKING/$VTP_DATA/Data/PlantModels/
    rm -Rf $WORKING/$VTP_DATA/VTP
    rm -Rf $WORKING/$VTP_DATA/PlantModels
fi

if [ $VTPF -eq 1 ]; then
    fetch_vtp_source
fi

exit 0
