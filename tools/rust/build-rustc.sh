#!/bin/sh
# The nightly rustc LegacyFox builds with, plus rustc-apcs-returns.patch,
# registered with rustup as "lf-nightly".
#
# 32-bit iOS returns small structs the APCS way: in r0 only when they are
# "integer-like" (a single field at offset 0), otherwise through memory.
# Stock rustc follows AAPCS (any struct up to 4 bytes in r0), so Rust and C++
# disagree on functions such as Servo_StyleSet_MediumFeaturesChanged, whose
# result is three bools, and every argument after it lands in the wrong place.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
CACHE=${LEGACYFOX_CACHE:-$HOME/.cache/legacyfox}
COMMIT=${LEGACYFOX_RUSTC_COMMIT:-8d1a76430406c877b35d0b627e7f796dcf0dfeca}
SRC=$CACHE/rust
if [ ! -d "$SRC" ]; then
    git clone --filter=blob:none --no-checkout https://github.com/rust-lang/rust "$SRC"
fi
cd "$SRC"
git fetch --depth 1 origin "$COMMIT"
git checkout -f FETCH_HEAD
git apply "$HERE/rustc-apcs-returns.patch"
cat > bootstrap.toml <<'TOML'
change-id = "ignore"
profile = "compiler"
[llvm]
download-ci-llvm = true
[rust]
channel = "nightly"
download-rustc = false
debug = false
debug-assertions = false
incremental = false
[build]
docs = false
TOML
./x.py build --stage 1 library
STAGE=$SRC/build/host/stage1
mkdir -p "$STAGE/lib/rustlib/src"
ln -sfn "$SRC" "$STAGE/lib/rustlib/src/rust"
cp "$(rustup which --toolchain nightly cargo)" "$STAGE/bin/"
rustup toolchain link lf-nightly "$STAGE"
echo "lf-nightly: $(rustc +lf-nightly -V)"
