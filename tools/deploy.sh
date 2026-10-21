#!/bin/sh
# Build LegacyFox.app with Gecko and put it on the test device:
# /var/mobile/Library/LegacyFox/LegacyFox.app, linked from /Applications
# (the system partition is too small for it).
#   tools/deploy.sh          # build, copy, uicache
#   tools/deploy.sh run      # ...and start it over ssh with tools/crashlog
#   NO_ENGINE=1 tools/deploy.sh   # skip the incremental engine build
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEVICE=${DEVICE:-legacyfox-device}
DEST=/var/mobile/Library/LegacyFox
pgrep -f "iproxy 2222" >/dev/null || (setsid nohup iproxy 2222 22 >/dev/null 2>&1 &)
[ -n "$NO_ENGINE" ] || "$ROOT/tools/mach.sh" build -j8 >/tmp/legacyfox-build.log 2>&1 || { grep " E " /tmp/legacyfox-build.log | head -20; exit 1; }
make -C "$ROOT" app
cp "$ROOT/prefs/legacyfox-dev.js" "$ROOT/shell/build/LegacyFox.app/Frameworks/defaults/pref/"
cd "$ROOT/shell/build"
# Gecko keeps compiled chrome JS in its startup cache; drop it with each new
# build so changed modules are read again.
tar cf - LegacyFox.app | ssh "$DEVICE" "rm -rf /var/mobile/Library/Caches/mozilla/firefox/*/startupCache; mkdir -p $DEST && cd $DEST && rm -rf LegacyFox.app && tar xf - && chown -R root:wheel LegacyFox.app && chown mobile:mobile $DEST && ln -sfn $DEST/LegacyFox.app /Applications/LegacyFox.app && su mobile -c uicache"
if [ "$1" = run ]; then
    # Started through SpringBoard (its URL scheme), as a user would; the
    # debug switch sends its output and crash reports to lf.log.
    ssh "$DEVICE" "mkdir -p /var/mobile/legacyfox-test" &&
        scp -O -q "$ROOT/tools/crashlog/crashlog.dylib" "$DEVICE:/var/mobile/legacyfox-test/"
    ssh "$DEVICE" "touch $DEST/debug; chown mobile $DEST/debug; killall LegacyFox 2>/dev/null; sleep 1; uiopen legacyfox:// ; sleep ${WAIT:-30}; cat $DEST/lf.log"
fi
