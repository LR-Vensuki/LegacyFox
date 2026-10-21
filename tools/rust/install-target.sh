#!/bin/sh
# Install armv7-apple-ios-legacy into the nightly rustc sysroot: the target
# spec, and a std built from source for it (the way gecko-w10m's
# uwp-install-std.sh does it).
#
# The Firefox build cannot use -Z build-std itself: std's own dependencies
# would be resolved against Firefox's vendored crates and do not match. With
# std in the sysroot, rustc finds the target by name like a built-in one.
#
# Rerun after every rustup update: std built by one rustc cannot be linked by
# another.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
TARGET=armv7-apple-ios-legacy
THEOS=${THEOS:-$HOME/theos}
TC=${LEGACYFOX_TC:-$THEOS/toolchain/linux/iphone/bin}
SDK=${LEGACYFOX_SDK:-$THEOS/sdks/iPhoneOS6.1.sdk}
DIR="$(rustc +${LEGACYFOX_RUST_TOOLCHAIN:-lf-nightly} --print sysroot)/lib/rustlib/$TARGET"

mkdir -p "$DIR/lib"
cp "$HERE/$TARGET.json" "$DIR/target.json"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
cargo +${LEGACYFOX_RUST_TOOLCHAIN:-lf-nightly} new --lib stdbuild >/dev/null 2>&1
cd stdbuild
printf '[profile.release]\npanic = "abort"\n' >> Cargo.toml
# Firefox links Rust with -Clto, which needs bitcode in std too.
RUSTC_BOOTSTRAP=1 RUSTFLAGS="-Cembed-bitcode=yes -Cpanic=abort -Zunstable-options" \
IPHONEOS_DEPLOYMENT_TARGET=4.0 \
CC_armv7_apple_ios_legacy="clang -target armv7-apple-ios9.0 -isysroot $SDK" \
AR_armv7_apple_ios_legacy="$TC/ar" \
    cargo +${LEGACYFOX_RUST_TOOLCHAIN:-lf-nightly} build --release -Z build-std=std,panic_abort --target "$TARGET"
# current cargo writes the rlibs as metadata stubs next to separate .rmeta
rm -f "$DIR"/lib/*.rlib "$DIR"/lib/*.rmeta
find target/$TARGET/release \( -name "*.rlib" -o -name "*.rmeta" \) ! -name "libstdbuild*" \
    -exec cp {} "$DIR/lib/" \;
echo "installed $(ls "$DIR"/lib/*.rlib | wc -l) std rlibs into $DIR/lib"
