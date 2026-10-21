#!/usr/bin/env python3
"""Aggregate tools/crashlog main-thread samples from lf.log into a profile.

usage: aggregate.py lf.log XUL [top]

Each sample is a pc plus a frame-pointer walk as XUL+offset; offsets are
looked up in the symbol table of the unstripped XUL in the objdir.
Prints self time (by pc) and inclusive time (any frame) per function.
"""
import bisect, collections, re, subprocess, sys

log, xul = sys.argv[1], sys.argv[2]
top = int(sys.argv[3]) if len(sys.argv) > 3 else 40
samples, cur = [], None
for line in open(log, errors="replace"):
    if "main thread sample" in line:
        cur = []
        samples.append(cur)
        continue
    m = re.match(r"\s+(pc|lr|ret)\s+0x[0-9a-f]+(?:\s+(\S+)\+0x([0-9a-f]+))?", line)
    if cur is not None and m:
        if m.group(1) == "lr":
            continue
        img, off = m.group(2), m.group(3)
        # return addresses point after the call: step back into it
        o = int(off, 16) - (1 if m.group(1) == "ret" else 0) if off else None
        cur.append((img, o))
    elif cur is not None and line.strip() and not line.startswith("  "):
        cur = None

offs = sorted({o for s in samples for img, o in s if img == "XUL" and o is not None})
# Function starts from the symbol table (the build has no DWARF to speak of).
nm = subprocess.run(["llvm-nm-21", "-n", "--defined-only", xul],
                    capture_output=True, text=True).stdout.split("\n")
syms = []
for line in nm:
    parts = line.split()
    if len(parts) == 3 and parts[1] in "tT":
        syms.append((int(parts[0], 16), parts[2]))
starts = [a for a, _ in syms]
want = {}
for o in offs:
    i = bisect.bisect_right(starts, o) - 1
    want[o] = syms[i][1] if i >= 0 else "?"
mangled = sorted(set(want.values()))
dem = subprocess.run(["llvm-cxxfilt-21", "-_"], input="\n".join(mangled),
                     capture_output=True, text=True).stdout.split("\n")
dem = dict(zip(mangled, dem))
names = {o: dem.get(m, m) for o, m in want.items()}

def name(f):
    img, o = f
    if img == "XUL":
        return names.get(o, "?")
    return (img or "?") + ("" if o is None else "")

selfc, incl = collections.Counter(), collections.Counter()
for s in samples:
    if not s:
        continue
    selfc[name(s[0])] += 1
    for n in {name(f) for f in s}:
        incl[n] += 1
n = len(samples)
print(f"{n} samples")
print("\n== self ==")
for k, v in selfc.most_common(top):
    print(f"{v:4d} {100*v/n:5.1f}%  {k[:150]}")
print("\n== inclusive ==")
for k, v in incl.most_common(top * 2):
    print(f"{v:4d} {100*v/n:5.1f}%  {k[:150]}")
