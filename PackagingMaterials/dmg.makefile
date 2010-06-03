#
# Build file for creating DMG files.
#
# The DMG packager looks for a template.dmg.bz2 for using as its 
# DMG template. If it doesn't find one, it generates a clean one.
#
# If you create a DMG template, you should make one containing all
# the files listed in $(SOURCE_FILES) below, and arrange everything to suit
# your style. The contents of the files themselves does not matter, so
# they can be empty (they will be overwritten later). 
#
# Remko Troncon 
# http://el-tramo.be/about
#


################################################################################
# Customizable variables
################################################################################

NAME=VTerrain
VERSION=$(shell date "+%Y%m%d")

SOURCE_DIR=${HOME}/vterrain/Release
SOURCE_FILES=README.txt Packages/VTP-DataFiles.pkg Packages/VTP-Applications.pkg VTP-Full-Install.mpkg 

PACKING_MATERIALS_DIR=${HOME}/vterrain/scripts/PackagingMaterials

BACKGROUND_IMG=$(PACKING_MATERIALS_DIR)/installer_bg.png

TEMPLATE_DMG=template.dmg


################################################################################
# DMG building. No editing should be needed beyond this point.
################################################################################

MASTER_DMG=$(SOURCE_DIR)/$(NAME)-$(VERSION).dmg
WC_DMG=wc.dmg
WC_DIR=wc

.PHONY: all
all: $(MASTER_DMG)

$(TEMPLATE_DMG): $(TEMPLATE_DMG).bz2
	bunzip2 -k $<

$(TEMPLATE_DMG).bz2: 
	@echo
	@echo --------------------- Generating empty template --------------------
	mkdir template
	hdiutil create -size 200m "$(TEMPLATE_DMG)" -srcfolder template -format UDRW -volname "$(NAME)" -quiet
	rmdir template
	bzip2 "$(TEMPLATE_DMG)"
	@echo

$(WC_DMG): $(TEMPLATE_DMG)
	cp $< $@

$(MASTER_DMG): $(WC_DMG) $(addprefix $(SOURCE_DIR)/,$(SOURCE_FILES))
	@echo
	@echo --------------------- Creating Disk Image --------------------
	mkdir -p $(WC_DIR)
	hdiutil attach "$(WC_DMG)" -noautoopen -quiet -mountpoint "$(WC_DIR)"
	for i in $(SOURCE_FILES); do  \
		rm -rf "$(WC_DIR)/$$i"; \
		ditto -rsrc "$(SOURCE_DIR)/$$i" "$(WC_DIR)/$$i"; \
	done
	cp -f $(BACKGROUND_IMG) $(WC_DIR)/.background
	WC_DEV=`hdiutil info | grep "$(WC_DIR)" | grep "Apple_HFS" | awk '{print $$1}'` && \
	hdiutil detach $$WC_DEV -quiet -force
	rm -f "$(MASTER_DMG)"
	hdiutil convert "$(WC_DMG)" -quiet -format UDZO -imagekey zlib-level=9 -o "$@"
#	rm -rf $(WC_DIR) $(WC_DMG) $(TEMPLATE_DMG)
	@echo

.PHONY: clean
clean:
	-rm -rf $(TEMPLATE_DMG) $(MASTER_DMG) $(WC_DMG)
