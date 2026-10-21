# shared toolchain settings: the theos toolchain and sdk, the same way
# LegacyRay uses them (no theos makefile framework).
#
#   make THEOS=/opt/theos LF_SDK=/opt/theos/sdks/iPhoneOS6.1.sdk

THEOS       ?= $(HOME)/theos
LF_TC       ?= $(THEOS)/toolchain/linux/iphone/bin
LF_SDK      ?= $(THEOS)/sdks/iPhoneOS6.1.sdk
# armv7 covers every A4-A6 device on ios 4 through 7
LF_IOS_MIN  ?= 4.0
LF_TRIPLE   ?= arm-apple-darwin11

LF_CC       := $(LF_TC)/clang -target $(LF_TRIPLE) -B $(LF_TC)
LF_ARCH     := -arch armv7 -miphoneos-version-min=$(LF_IOS_MIN)
LF_SYSROOT  := -isysroot $(LF_SDK)
LF_LDID     := $(LF_TC)/ldid
LF_STRIP    := $(LF_TC)/strip

# ios 4 dpkg only understands gzip members
LF_DEB_COMPRESSION ?= gzip

ifeq ($(wildcard $(LF_TC)/clang),)
$(error no clang at $(LF_TC): install theos or set THEOS / LF_TC)
endif
ifeq ($(wildcard $(LF_SDK)),)
$(error no sdk at $(LF_SDK): put iPhoneOS6.1.sdk into $(THEOS)/sdks or set LF_SDK)
endif
