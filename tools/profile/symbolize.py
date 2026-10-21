#!/usr/bin/env python3
"""Fill in XUL function names in tools/crashlog output (lf.log).

usage: symbolize.py lf.log XUL > out
"""
import bisect, re, subprocess, sys

log, xul = sys.argv[1], sys.argv[2]
lines = open(log, errors="replace").read().split("\n")
pat = re.compile(r"XUL\+0x([0-9a-f]+)")
offs = sorted({int(m.group(1), 16) for l in lines for m in pat.finditer(l)})
syms = []
for line in subprocess.run(["llvm-nm-21", "-n", "--defined-only", xul],
                           capture_output=True, text=True).stdout.split("\n"):
    p = line.split()
    if len(p) == 3 and p[1] in "tT":
        syms.append((int(p[0], 16), p[2]))
starts = [a for a, _ in syms]
mangled = {}
for o in offs:
    i = bisect.bisect_right(starts, o - 1) - 1
    mangled[o] = syms[i][1] if i >= 0 else "?"
uniq = sorted(set(mangled.values()))
dem = subprocess.run(["llvm-cxxfilt-21", "-_"], input="\n".join(uniq),
                     capture_output=True, text=True).stdout.split("\n")
dem = dict(zip(uniq, dem))
for l in lines:
    m = pat.search(l)
    if m:
        l = l[:m.end()] + "  " + dem.get(mangled[int(m.group(1), 16)], "?")[:160]
    print(l)
