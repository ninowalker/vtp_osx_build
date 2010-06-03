#!/bin/bash -e

WORKING=$HOME/vterrain

VTP_DATA_SRC=$WORKING/vtp-data
PACK_MATERIALS=`dirname $0`/PackagingMaterials

PACKAGER=/Developer/Applications/Utilities/PackageMaker.app/Contents/MacOS/PackageMaker

function chkerror { 
    if [ $? -ne 0 ]; then
	echo $1
	exit 1 
    fi 
}

function prepare_files {
    D=$WORKING/Release
    mkdir -p $D/Binaries
    mkdir -p $D/DataFiles

    cp -RHf $WORKING/build.vtp/*.{app,xml} $D/Binaries
    cp -RHf $WORKING/build.shared/Shared $D/Binaries
    cp $WORKING/vtp/TerrainApps/Enviro/license.txt $D/Binaries

    cp -RHf $VTP_DATA_SRC/Data $D/DataFiles
    cp -RHf $VTP_DATA_SRC/WorldMap $D/DataFiles

    cp $PACK_MATERIALS/Release_email $D/README.txt

}


function create_a_package {
    F=$1
    S=$2
    D=$3
    
    echo $PACKAGER -build -p $D/$F -f $S \
	-ds -v -i $PACK_MATERIALS/$F.info.plist \
	-d $PACK_MATERIALS/$F.description.plist
    $PACKAGER -build -p $D/$F -f $S \
	-ds -v -i $PACK_MATERIALS/$F.info.plist \
	-d $PACK_MATERIALS/$F.description.plist
    chkerror
}

function create_packages {
    SRC=$WORKING/Release
    DEST=$WORKING/Release/Packages

    mkdir -p $DEST

    create_a_package VTP-DataFiles.pkg $SRC/DataFiles $DEST
    create_a_package VTP-Applications.pkg $SRC/Binaries $DEST
    
    DIR=`pwd`
    (cd $DEST && \
    $PACKAGER -build -ms . -p $DEST/../VTP-Full-Install.mpkg \
	-d $DIR/$PACK_MATERIALS/VTP-Full-Install.description.plist \
	-i $DIR/$PACK_MATERIALS/VTP-Full-Install.info.plist )
    perl -i -p -e 's/\.\./\.\.\/Packages/' $DEST/../VTP-Full-Install.mpkg/Contents/Info.plist

    chkerror
    
}

function create_image {
    cd PackagingMaterials
    make -f dmg.makefile
}

prepare_files
create_packages
create_image