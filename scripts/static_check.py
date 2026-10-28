#!/usr/bin/env python3
"""Cheap static sanity checks for Dart code when no Flutter SDK is available.
It does NOT replace `flutter analyze`. It catches: unbalanced brackets, imports of
project files that do not exist, leftover mock imports, hard-coded secrets, live Stripe keys.
Usage: python3 scripts/static_check.py
"""
import os, re, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
problems = []
files = []
for base in ("lib", "test"):
    for d, _, fs in os.walk(os.path.join(root, base)):
        files += [os.path.join(d, f) for f in fs if f.endswith(".dart")]

def strip(src):
    # remove comments and string contents so brackets inside them are ignored
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            while i < n and src[i] != "\n": i += 1
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2); i = n if j < 0 else j + 2
        elif c in "'\"":
            triple = src.startswith(c * 3, i)
            q = c * 3 if triple else c
            raw = i > 0 and src[i - 1] == "r"
            i += len(q)
            while i < n and not src.startswith(q, i):
                if src[i] == "\\" and not raw: i += 1
                elif src[i] == "$" and src[i+1:i+2] == "{" and not raw:
                    # interpolation: keep a balanced placeholder
                    depth, i = 1, i + 2
                    while i < n and depth:
                        depth += {"{": 1, "}": -1}.get(src[i], 0); i += 1
                    continue
                i += 1
            i += len(q); out.append('""')
            continue
        else:
            out.append(c); i += 1
            continue
    return "".join(out)

pairs = {")": "(", "]": "[", "}": "{"}
for f in files:
    rel = os.path.relpath(f, root)
    src = open(f, encoding="utf-8").read()
    s = strip(src)
    stack = []
    for ch in s:
        if ch in "([{": stack.append(ch)
        elif ch in ")]}":
            if not stack or stack.pop() != pairs[ch]:
                problems.append(f"{rel}: unbalanced '{ch}'"); break
    else:
        if stack: problems.append(f"{rel}: unclosed '{stack[-1]}'")
    for m in re.finditer(r"import\s+'package:bookswaphub/([^']+)'", src):
        if not os.path.exists(os.path.join(root, "lib", m.group(1))):
            problems.append(f"{rel}: missing import {m.group(1)}")
    if "data/mock" in src: problems.append(f"{rel}: references mock data")
    if not rel.startswith("test") and re.search(r"sk_(live|test)_[A-Za-z0-9]{8,}|whsec_[A-Za-z0-9]{8,}|pk_live_", src):
        problems.append(f"{rel}: looks like a hard-coded Stripe key")
    if re.search(r"AIza[0-9A-Za-z_\-]{30,}", src):
        problems.append(f"{rel}: looks like a Google API key")

print(f"checked {len(files)} Dart files")
if problems:
    print("\n".join(problems)); sys.exit(1)
print("OK: no static problems found")
