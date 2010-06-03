
WORKING=$(HOME)/vterrain

TEMP_STAGING_DIR=/Library/Frameworks/VTPX.framework/Versions/A


#DINSTALL_BASE=/usr/local
DEST_INSTALL_BASE=/Library/Frameworks/VTPX.framework/Versions/A

TEMP_DEST_PREFIX=/Library/Frameworks/VTPX.framework/Versions/A


DLIB_DIR=$(DEST_INSTALL_BASE)/lib
DINCLUDE_DIR=$(DEST_INSTALL_BASE)/include
DBIN_DIR=$(DEST_INSTALL_BASE)/bin

GDAL_VERSION=1.5.1
GDAL_PYTON_FLAG= --with-python
#GDAL_PYTON_FLAG= --without-python

PROJ_VERSION=4.5.0

WX_VERSION=2.8.7

OSG_VERSION=2.3.9

.phony: $(TEMP_DEST_PREFIX)

default: $(TEMP_DEST_PREFIX)  libmini gdal proj wx osg

build: install-fink-dependencies build-libmini build-gdal build-proj build-wx build-osg

install: $(TEMP_DEST_PREFIX) install-libmini install-gdal install-proj install-wx install-osg

$(TEMP_DEST_PREFIX):
	mkdir -p $(TEMP_DEST_PREFIX)/lib $(TEMP_DEST_PREFIX)/share $(TEMP_DEST_PREFIX)/include

install-fink-dependencies:
	./fink-get.sh libxml2
	./fink-get.sh libnetcdf	netcdf	
	./fink-get.sh libpng.3 libpng3
	./fink-get.sh libjpeg
	./fink-get.sh libtiff
	./fink-get.sh libwwwcore libwww
	./fink-get.sh libcurl curl
#	./fink-get.sh libtff freetype

build-libmini:
	cd $(WORKING)/libMini/mini && \
	./build.sh

install-libmini:
	cd $(WORKING)/libMini/mini && \
	\
	cp -fp libMini.a $(DLIB_DIR) && \
	cp -fp *.h $(DINCLUDE_DIR)

libmini: build-libmini install-libmini

# RE hack: http://article.gmane.org/gmane.comp.gis.gdal.devel/13803
build-gdal:
	cd $(WORKING)/gdal/gdal-$(GDAL_VERSION)/ && \
		LDFLAGS=-L/sw/lib CFLAGS=-I/sw/include CXXFLAGS=-I/sw/include \
	    		./configure --prefix=$(TEMP_DEST_PREFIX) --disable-static \
			--datarootdir=$(TEMP_DEST_PREFIX)/share/gdal \
	    		$(GDAL_PYTHON_FLAG) --with-tiff=/sw --with-png=/sw \
			--with-jpeg=/sw && \
	\
	perl -i -p -e 's%(\$\(LD\) \$\(LNK_FLAGS\) .*?)\.o %$1.lo %' \
	    apps/GNUmakefile && \
	\
	make

install-gdal:
	cd $(WORKING)/gdal/gdal-$(GDAL_VERSION)/ && \
		make install

gdal: build-gdal install-gdal


ifeq ($(WXPACKAGE),wxPython)
build-wx: build-wxmac build-wxpython-c
install-wx: install-wxmac build-wxpython-python install-wxpython
else
build-wx: build-wxmac
install-wx: install-wxmac
endif

wx: build-wx install-wx

build-wxmac:
	cd $(WORKING)/wx/wx*$(WX_VERSION)/ && \
		mkdir -p bld && cd bld && \
	LDFLAGS=-L/sw/lib CFLAGS=-I/sw/include CXXFLAGS=-I/sw/include \
		../configure --with-mac \
		--prefix=$(TEMP_DEST_PREFIX) \
	        --with-opengl --enable-geometry --enable-graphics_ctx \
	        --enable-sound --with-sdl \
	        --enable-mediactrl \
	        --enable-display \
		--enable-static=no --enable-shared=yes \
		--enable-monolithic  \
		--enable-optimize --enable-unicode \
		$(WX_FLAGS) && \
	\
	make && \
	make -C contrib/src/gizmos && \
	make -C contrib/src/stc 

install-wxmac:
	cd $(WORKING)/wx/wx*$(WX_VERSION)/bld && \
	\
	make install  && \
	make install contrib/src/gizmos  && \
	make install contrib/src/stc


build-wxpython-c:
	cd $(WORKING)/wx/wxPython*$(WX_VERSION)/bld && \
		make -C contrib/src/gizmos &&
		make -C contrib/src/stc

build-wxpython-python:
	cd $(WORKING)/wx/wxPython*$(WX_VERSION)/wxPython && \
	\	
	python2.5 setup.py build_ext --inplace \
		WX_CONFIG=$(DBIN_DIR)/bin/wx-config \
		MONOLITHIC=1 UNICODE=1 USE_SWIG=0 && \
## see the tech note here:
## http://lists.apple.com/archives/darwin-dev/2006/Apr/msg00042.html
	if [ ! -h /Developer/SDKs/MacOSX10.4u.sdk/sw ]; then \
 	    echo "## ld fails if there isn't a link to /sw in /Developer/SDKs/MacOSX10.4u.sdk, so creating link" && \
	    sudo ln -s /sw /Developer/SDKs/MacOSX10.4u.sdk/sw; \
	fi

install-wxpython:
	cd $(WORKING)/wx/wxPython*$(WX_VERSION)/wxPython && \
	sudo python2.5 setup.py install

build-proj:
	cd $(WORKING)/PROJ/proj-$(PROJ_VERSION) && \
	./configure --prefix=$(TEMP_DEST_PREFIX) && \
	make

install-proj:
	cd $(WORKING)/PROJ/proj-$(PROJ_VERSION) && \
	make install

proj: build-proj install-proj

#	    -DDEFAULT_GLU_TESS_CALLBACK_TRIPLEDOT=OFF
build-osg:
	cd $(WORKING)/osg/OpenSceneGraph-$(OSG_VERSION) && \
	\
	cmake -C . -DCMAKE_BUILD_TYPE=Release -DOSG_USE_FLOAT_MATRIX:BOOL=ON \
	    -DBUILD_OSG_APPLICATIONS=OFF -DCMAKE_OSX_ARCHITECTURES=i386 \
	    -DOSG_GLU_TESS_CALLBACK_TRIPLEDOT:BOOL=OFF \
	    -DCMAKE_INSTALL_PREFIX:PATH=$(TEMP_DEST_PREFIX) && \
	\
	make

install-osg:
	cd $(WORKING)/osg/OpenSceneGraph-$(OSG_VERSION) && \
	\
	make install


osg: build-osg install-osg