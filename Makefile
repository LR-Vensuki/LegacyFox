# LegacyFox: Gecko for iOS 4-7 with a UIKit shell (docs/PLAN.md).
#
#   make            the shell, shell/build/LegacyFox.app
#   make app        the shell with Gecko from LF_OBJ in its Frameworks/
#   make package    packages/com.legacyreborn.legacyfox_<version>_iphoneos-arm.deb
#   make install    copy the .deb to THEOS_DEVICE_IP and dpkg -i it
#   make clean
include make/config.mk

PACKAGE := com.legacyreborn.legacyfox
VERSION := $(shell sed -n 's/^Version: //p' layout/DEBIAN/control)
DEB     := packages/$(PACKAGE)_$(VERSION)_iphoneos-arm.deb
STAGE   := .stage

LF_DEB_TOOL ?= $(if $(wildcard $(THEOS)/bin/dm.pl),$(THEOS)/bin/dm.pl,dpkg-deb --root-owner-group)

THEOS_DEVICE_IP ?=
THEOS_DEVICE_PORT ?= 22
THEOS_DEVICE_USER ?= root

LF_OBJ  ?= $(HOME)/lf-obj
APP     := shell/build/LegacyFox.app

.PHONY: all shell app package install clean
all: shell

shell:
	$(MAKE) -C shell

# Gecko's files go next to XUL in Frameworks/ (the layout its iOS port
# expects), symlinks resolved, test-only tools left out; binaries stripped
# and signed with the shell's entitlements (dynamic-codesigning for the JIT).
app: shell
	rsync -rtL --delete --exclude 'Test*' --exclude 'test_*' --exclude '*_unittest' \
	      --exclude 'certutil' --exclude 'pk12util' --exclude 'pingsender' \
	      --exclude 'nsinstall' --exclude 'gmp-fake*' --exclude '.*' \
	      $(LF_OBJ)/dist/bin/ $(APP)/Frameworks/
	mkdir -p $(APP)/Frameworks/defaults/pref
	cp prefs/legacyfox.js $(APP)/Frameworks/defaults/pref/
	for f in $(APP)/Frameworks/XUL $(APP)/Frameworks/*.dylib; do \
	    $(LF_STRIP) -x $$f && $(LF_LDID) -S $$f; done
	$(LF_LDID) -Sshell/Resources/LegacyFox.entitlements $(APP)/LegacyFox
	@du -sh $(APP)

package: app
	@rm -rf $(STAGE)
	@mkdir -p $(STAGE)/var/mobile/Library/LegacyFox packages
	cp -R layout/. $(STAGE)/
	cp -R shell/build/LegacyFox.app $(STAGE)/var/mobile/Library/LegacyFox/
	$(LF_DEB_TOOL) -Z$(LF_DEB_COMPRESSION) -b $(STAGE) $(DEB)
	@rm -rf $(STAGE)
	@echo "==> $(DEB)"

install: package
	@if [ -z "$(THEOS_DEVICE_IP)" ]; then echo "set THEOS_DEVICE_IP=<device ip>"; exit 1; fi
	scp -P $(THEOS_DEVICE_PORT) $(DEB) $(THEOS_DEVICE_USER)@$(THEOS_DEVICE_IP):/var/mobile/
	ssh -p $(THEOS_DEVICE_PORT) $(THEOS_DEVICE_USER)@$(THEOS_DEVICE_IP) \
		"dpkg -i /var/mobile/$(notdir $(DEB)) && rm -f /var/mobile/$(notdir $(DEB))"

clean:
	$(MAKE) -C shell clean
	rm -rf $(STAGE) packages
