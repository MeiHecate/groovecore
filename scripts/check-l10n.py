#!/usr/bin/env python3
"""Every tr("key") in App/ and every built-in exercise has a fr + en string."""
import csv
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
with open(root / "scripts/strings.tsv", encoding="utf-8") as f:
    rows = [r for r in csv.reader(f, delimiter="\t", quoting=csv.QUOTE_NONE) if r and not r[0].startswith("#")]
keys = {r[0] for r in rows if len(r) == 3 and r[1].strip() and r[2].strip()}

used = set()
for path in (root / "App").rglob("*.swift"):
    for key in re.findall(r'(?:\btr\(\s*|\bkey = )"([^"]+)"(?!\s*\+)', path.read_text(encoding="utf-8")):
        if "\\(" not in key:
            used.add(key)
catalog = (root / "GrooveKit/Sources/GrooveKit/ExerciseCatalog.swift").read_text(encoding="utf-8")
used |= {f"exercise.{k}" for k in re.findall(r'key: "([A-Za-z]+)"', catalog)}

for lang in ("fr", "en"):
    generated = root / "App/Resources" / f"{lang}.lproj/Localizable.strings"
    if not generated.exists():
        sys.exit(f"{generated} absent ou périmé : lancer python3 scripts/gen-strings.py")
    generated_keys = set(re.findall(r'^"((?:[^"\\]|\\.)*)" = ', generated.read_text(encoding="utf-8"), re.MULTILINE))
    if generated_keys != keys:
        sys.exit(f"{generated} absent ou périmé : lancer python3 scripts/gen-strings.py")

missing = sorted(used - keys)
if missing:
    print("Clés sans traduction fr + en :")
    print("\n".join(f"  {k}" for k in missing))
    sys.exit(1)
unused = sorted(keys - used)
if unused:
    print("Info, clés non utilisées : " + ", ".join(unused))
print(f"OK : {len(used)} clés utilisées, toutes traduites en fr et en")
