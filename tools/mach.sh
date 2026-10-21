#!/bin/sh
# Run mach on the engine with LegacyFox's tools on PATH.
#   tools/mach.sh build          # the whole engine (mozconfig.armv7-ios)
#   JS=1 tools/mach.sh build     # SpiderMonkey alone (mozconfig.js-armv7-ios)
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CACHE=${LEGACYFOX_CACHE:-$HOME/.cache/legacyfox}
export PATH="$HOME/.cargo/bin:$CACHE/node/bin:$CACHE/cmake/bin:$PATH"
export MOZBUILD_STATE_PATH=${MOZBUILD_STATE_PATH:-$HOME/.mozbuild}
if [ -n "$JS" ]; then
    export MOZCONFIG="$ROOT/mozconfig/mozconfig.js-armv7-ios"
else
    export MOZCONFIG="$ROOT/mozconfig/mozconfig.armv7-ios"
fi
cd "$ROOT/engine/firefox" && exec ./mach "$@"
