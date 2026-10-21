# LegacyFox.app shell for armv7, ios 4-7. manual retain/release: ARC needs
# ios 5 for weak references and libarclite is not in the theos toolchain.
# linked against the 6.1 sdk on purpose: ios 7 then keeps the ios 6 look.
include ../make/config.mk

APP_NAME := LegacyFox
BUILD    ?= build
OBJDIR   := $(BUILD)/obj
APP      := $(BUILD)/$(APP_NAME).app
BIN      := $(APP)/$(APP_NAME)

# GECKO=1 links the engine (XUL from the engine's objdir); GECKO=0 builds the
# shell alone, with Sources/Gecko/LFGeckoStub.m in place of Gecko.
GECKO    ?= 1
LF_OBJ   ?= $(HOME)/lf-obj
GECKO_SRC := ../engine/firefox
OBJC_SRC := $(wildcard Sources/*.m) Sources/Gecko/LFGecko.m
ifeq ($(GECKO),0)
OBJC_SRC += Sources/Gecko/LFGeckoStub.m
endif
OBJC_OBJ := $(patsubst Sources/%.m,$(OBJDIR)/%.o,$(OBJC_SRC))

WARN      := -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers
CFLAGS    := $(LF_ARCH) $(LF_SYSROOT) -O2 -g0 $(WARN) -ISources -I$(GECKO_SRC)/widget/uikit -DMOZ_IOS_LEGACY=1
OBJCFLAGS := $(CFLAGS) -fno-objc-arc -fblocks -include Sources/LFPrefix.h
LDFLAGS   := $(LF_ARCH) $(LF_SYSROOT) -Wl,-dead_strip \
             -framework UIKit -framework Foundation -framework CoreGraphics \
             -framework QuartzCore -framework OpenGLES
ifneq ($(GECKO),0)
# Gecko (XUL and its dylibs, all @rpath) lives in the bundle's Frameworks/.
LDFLAGS   += $(LF_OBJ)/dist/bin/XUL -Wl,-rpath,@executable_path/Frameworks
endif

RESOURCES := Resources/Info.plist $(wildcard Resources/*.png) $(wildcard Resources/Fennec/*.png) Resources/Fennec/ninepatch.plist

.PHONY: all clean
all: $(BIN)

$(OBJDIR)/%.o: Sources/%.m $(wildcard Sources/*.h Sources/Gecko/*.h)
	@mkdir -p $(dir $@)
	@echo "  objc  $<"
	@$(LF_CC) $(OBJCFLAGS) -c $< -o $@

$(BIN): $(OBJC_OBJ) $(RESOURCES) Resources/LegacyFox.entitlements
	@mkdir -p $(APP)
	@echo "  link  $(APP_NAME)"
	@$(LF_CC) $(OBJC_OBJ) -o $@ $(LDFLAGS)
	@$(LF_STRIP) -x $@
	@$(LF_LDID) -SResources/LegacyFox.entitlements $@
	@cp $(RESOURCES) $(APP)/

clean:
	rm -rf $(BUILD)
