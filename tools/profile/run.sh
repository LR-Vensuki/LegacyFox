#!/bin/sh
# One measured run on the test device: the debug file gets the given lines,
# LegacyFox starts through SpringBoard, and after SECONDS its log comes back
# with a summary of memory, GPU fallbacks and crashes.
#   tools/profile/run.sh OUT.log SECONDS 'LF_SWGL_GPU=1' 'LF_START_URL=...' ...
#   tools/profile/run.sh -s OUT.log      # only the summary of a log
# Optional: SAMPLE_FROM=s SAMPLES=n [SAMPLE_SIG=USR2] take n thread samples
# SAMPLE_GAP (0.5) s apart from s seconds on (tools/profile/threads.py reads them);
# WINCH_AT=s logs the address space map at s seconds.
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DEVICE=${DEVICE:-legacyfox-device}
DEST=/var/mobile/Library/LegacyFox
if [ "$1" = -s ]; then
    OUT=$2
else
    OUT=$1; SECONDS_=$2; shift 2
    DEBUG=$(printf '%s\n' "$@")
    PROBES=""
    [ -n "$WINCH_AT" ] && PROBES="(sleep $WINCH_AT; killall -WINCH LegacyFox) &"
    [ -n "$SAMPLES" ] && PROBES="$PROBES (sleep ${SAMPLE_FROM:-30}; i=0; while [ \$i -lt $SAMPLES ]; do killall -${SAMPLE_SIG:-USR2} LegacyFox; sleep ${SAMPLE_GAP:-0.5}; i=\$((i+1)); done) &"
    ssh "$DEVICE" "mkdir -p /var/mobile/legacyfox-test"
    scp -O -q "$ROOT/tools/crashlog/crashlog.dylib" "$DEVICE:/var/mobile/legacyfox-test/"
    # UI steps change the saved tabs: they come back after the run.
    ssh "$DEVICE" "killall LegacyFox 2>/dev/null; sleep 1
cp -p $DEST/session.plist $DEST/session.plist.run 2>/dev/null
printf '%s\n' '$DEBUG' > $DEST/debug; chown mobile $DEST/debug; rm -f $DEST/lf.log
uiopen legacyfox:// ; $PROBES sleep $SECONDS_
if killall -0 LegacyFox 2>/dev/null; then echo 'LegacyFox: still running at the end'; else echo 'LegacyFox: not running at the end'; fi
killall LegacyFox 2>/dev/null; sleep 1
[ -f $DEST/session.plist.run ] && mv $DEST/session.plist.run $DEST/session.plist; true" > "$OUT.end"
    scp -O -q "$DEVICE:$DEST/lf.log" "$OUT"
    cat "$OUT.end" >> "$OUT"; rm -f "$OUT.end"
fi
echo "== $OUT: $(wc -l < "$OUT") lines"
grep -a -m3 -E 'SWGL pixel shading on the GPU' "$OUT" | cut -c1-200 || true
grep -a -E 'process [0-9]+ MB resident' "$OUT" | sed -E 's/.* process ([0-9]+) MB resident, ([0-9]+) MB mapped.*/\1 \2/' |
    awk '{n++; if ($2>m) m=$2; if ($1>r) r=$1; last=$0} END {if (n) printf "frames %d, max mapped %d MB, max resident %d MB, last %s\n", n, m, r, last}'
grep -a -E 'address space [0-9]+ MB by tag' "$OUT" | tail -n 1 | cut -c1-240 || true
grep -a -cE 'gpu: CPU (draw|for)' "$OUT" | sed 's/^/CPU fallbacks: /' || true
grep -a -nE "can't allocate|Assertion failure|MOZ_CRASH|Hit MOZ_|crashlog: signal|EXC_|Terminated|running at the end|applicationWillResignActive|applicationDidEnterBackground" "$OUT" | cut -c1-200 | head -20 || true
# Main-thread stalls: gaps of 1.5 s or more between scroll steps.
grep -a 'GeckoView.Module.*ScrollBy' "$OUT" | cut -f1 | awk 'NR==1{f=$1} {if (NR>1 && $1-p>=1500) printf "stall %.1f s at %.1f s\n", ($1-p)/1000, (p-f)/1000; p=$1; n++} END {if (n) printf "scroll steps %d over %.0f s\n", n, (p-f)/1000}' || true
