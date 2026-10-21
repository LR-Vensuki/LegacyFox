#!/bin/sh
# Everything the engine build expects on SuperPC, in order. Safe to rerun.
#   - ~/.cache/legacyfox/ld/ld: a link to theos' ld64, for clang's -B
#   - ~/.cache/legacyfox/libclang/libclang.so: for bindgen
#   - the Rust target and its std in the nightly sysroot
#   - static libc++ 21 for armv7
#   - compat/build/liblegacyfox_compat.a
# Needs theos with iPhoneOS6.1.sdk, rustup nightly with rust-src, cbindgen,
# and cmake/ninja/node in ~/.cache/legacyfox (see tools/cxx/README.md).
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CACHE=${LEGACYFOX_CACHE:-$HOME/.cache/legacyfox}
THEOS=${THEOS:-$HOME/theos}
mkdir -p "$CACHE/ld"
ln -sf "$THEOS/toolchain/linux/iphone/bin/ld" "$CACHE/ld/ld"
mkdir -p "$CACHE/libclang"
ln -sf "$(ls /usr/lib/llvm-*/lib/libclang-*.so.1 | sort -V | tail -1)" "$CACHE/libclang/libclang.so"
[ -d "$HOME/.rustup/toolchains/lf-nightly" ] || sh "$ROOT/tools/rust/build-rustc.sh"
sh "$ROOT/tools/rust/install-target.sh"
[ -f "$CACHE/libcxx-armv7/lib/libc++.a" ] || sh "$ROOT/tools/build-libcxx.sh"
make -C "$ROOT/compat"
