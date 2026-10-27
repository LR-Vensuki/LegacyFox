#!/usr/bin/env python3
"""Where the CPU goes, per thread and per kind of work, from tools/crashlog
all-thread samples (kill -USR2) in lf.log.

usage: threads.py lf.log XUL

A thread counts as busy in a sample when its pc is not in a kernel wait.
For busy samples on any thread, the work is classed by the XUL functions on
the stack: SWGL fragment shaders (*_frag), SWGL vertex shaders (*_vert),
SWGL rasterizing and compositing (glsl::/swgl), the rest of WebRender
(webrender::), layout/style/JS and other.
"""
import bisect, collections, re, subprocess, sys

log, xul = sys.argv[1], sys.argv[2]
syms = []
for line in subprocess.run(["llvm-nm-21", "-n", "--defined-only", xul], capture_output=True, text=True).stdout.split("\n"):
    p = line.split()
    if len(p) == 3 and p[1] in "tT":
        syms.append((int(p[0], 16), p[2]))
starts = [a for a, _ in syms]
names = {}

def name(off):
    i = bisect.bisect_right(starts, off) - 1
    return syms[i][1] if i >= 0 else "?"

samples = []   # (thread name, [(image, offset, symbol)])
cur = None
for line in open(log, errors="replace"):
    m = re.match(r"\*\*\* thread \d+ ?(.*?)(?: \(stack \d+ KB\))?$", line.strip())
    if m:
        cur = (m.group(1).strip() or "(unnamed)", [])
        samples.append(cur)
        continue
    m = re.match(r"\s+(pc|lr|ret)\s+0x[0-9a-f]+\s+(\S+)\+0x([0-9a-f]+)\s*(\S*)", line)
    if m and cur:
        img, off, sym = m.group(2), int(m.group(3), 16), m.group(4)
        cur[1].append((img, off, sym))

mangled = sorted({name(o) for _, fr in samples for img, o, _ in fr if img == "XUL"})
dem = dict(zip(mangled, subprocess.run(["llvm-cxxfilt-21"], input="\n".join(mangled), capture_output=True,
                                       text=True).stdout.split("\n")))

WAIT = ("mach_msg_trap", "semaphore_", "__psynch", "kevent", "__select", "__semwait", "__workq_kernreturn",
        "__wait4", "poll", "__accept", "__recvfrom", "read", "__disable_threadsignal")

def kind(frames):
    syms = [dem.get(name(o), "?") if img == "XUL" else sym for img, o, sym in frames]
    text = " ".join(syms)
    if re.search(r"_frag::", text):
        return "SWGL fragment shaders"
    if re.search(r"_vert::", text):
        return "SWGL vertex shaders"
    if re.search(r"glsl::|swgl|Composite|commit|draw_quad|draw_span|blend_span|clear_buffer", text):
        return "SWGL raster/composite"
    if "webrender" in text or "wr_" in text:
        return "WebRender (CPU, not drawing)"
    if re.search(r"js::|JS::|Interpret|jit::", text):
        return "JavaScript"
    if re.search(r"nsLayout|nsIFrame|PresShell|ReflowInput|nsBlockFrame|nsLineLayout|Servo|style::|selectors::|nsDisplay", text):
        return "layout/style/display lists"
    if re.search(r"gfx|Image|image::|Decoder|png|jpeg|webp", text):
        return "images/gfx"
    return "other"

busy = collections.Counter()
per_thread = collections.Counter()
per_kind = collections.Counter()
total_per_thread = collections.Counter()
for tname, fr in samples:
    total_per_thread[tname] += 1
    if not fr:
        continue
    top = fr[0][2] if fr[0][0] != "XUL" else ""
    if any(top.startswith(w) for w in WAIT) or (fr[0][0] == "libsystem_kernel.dylib" and top):
        continue
    per_thread[tname] += 1
    per_kind[kind(fr)] += 1

n = sum(per_kind.values())
print("busy samples:", n)
print("\nby kind of work:")
for k, c in per_kind.most_common():
    print(f"  {c:5d} {100 * c / n:5.1f}%  {k}")
print("\nbusy threads:")
for t, c in per_thread.most_common(12):
    print(f"  {c:5d} {100 * c / n:5.1f}%  {t}")
