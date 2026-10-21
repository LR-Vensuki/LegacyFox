#!/bin/sh
# rustc's linker for armv7-apple-ios-legacy: theos clang + ld64, the 6.1 sdk.
exec "${LEGACYFOX_TC:-$HOME/theos/toolchain/linux/iphone/bin}/clang" -target armv7-apple-ios4.0 -B "${LEGACYFOX_TC:-$HOME/theos/toolchain/linux/iphone/bin}" -isysroot "${LEGACYFOX_SDK:-$HOME/theos/sdks/iPhoneOS6.1.sdk}" "$@"
