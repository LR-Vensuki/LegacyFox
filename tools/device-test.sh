#!/bin/sh
# Run the toolchain tests and the SpiderMonkey shell on a jailbroken device
# over USB (iproxy to its OpenSSH), the way the other LegacyReborn projects
# test from SuperPC.
#
#   tools/device-test.sh            # ssh host "legacyfox-device" (~/.ssh/config:
#                                   # localhost:2222 through iproxy, key login)
#   DEVICE=root@192.168.1.5 tools/device-test.sh
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEVICE=${DEVICE:-legacyfox-device}
OBJ=${LEGACYFOX_JS_OBJ:-$HOME/lf-obj-js}
LDID=${LEGACYFOX_TC:-$HOME/theos/toolchain/linux/iphone/bin}/ldid
DIR=/var/mobile/legacyfox-test

if [ "$DEVICE" = legacyfox-device ] && ! pgrep -f "iproxy 2222" >/dev/null; then
    iproxy 2222 22 >/dev/null 2>&1 &
    trap 'kill $! 2>/dev/null' EXIT
    sleep 1
fi
SSH="ssh $DEVICE"

STAGE=$(mktemp -d)
cp "$ROOT/tools/rust/hello/hello-armv7" "$ROOT/tools/cxx/hello-cxx-armv7" \
   "$OBJ/dist/bin/js" "$OBJ/dist/bin/libmozglue.dylib" "$STAGE/"
for f in "$STAGE"/*; do "$LDID" -S"$ROOT/shell/Resources/LegacyFox.entitlements" "$f"; done
cat > "$STAGE/test.js" <<'JS'
function fib(n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }
let t = Date.now();
let r = fib(25);
print(`fib(25)=${r} in ${Date.now() - t} ms`);
print(new Intl.NumberFormat("ru-RU").format(1234567.891));
print([3, 1, 2].toSorted().join(","), "x".at(-1), Object.groupBy([1, 2, 3], n => n % 2 ? "odd" : "even").odd);
JS

$SSH "mkdir -p $DIR"
scp -O -q "$STAGE"/* "$DEVICE:$DIR/"
rm -rf "$STAGE"
$SSH "uname -a; sw_vers 2>/dev/null || true
cd $DIR
echo '== rust';  ./hello-armv7; echo rc=\$?
echo '== c++';   ./hello-cxx-armv7; echo rc=\$?
echo '== js (interpreter)'; DYLD_LIBRARY_PATH=$DIR ./js --no-baseline --no-ion test.js; echo rc=\$?
echo '== js (jit)';         DYLD_LIBRARY_PATH=$DIR ./js test.js; echo rc=\$?"
