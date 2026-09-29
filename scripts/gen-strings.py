#!/usr/bin/env python3
"""scripts/strings.tsv -> App/Resources/{fr,en}.lproj/Localizable.strings"""
import csv
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parent.parent
with open(root / "scripts/strings.tsv", encoding="utf-8") as f:
    rows = [r for r in csv.reader(f, delimiter="\t", quoting=csv.QUOTE_NONE) if r and not r[0].startswith("#")]

seen = set()
for r in rows:
    if len(r) != 3 or not all(x.strip() for x in r):
        sys.exit(f"ligne invalide (3 colonnes non vides attendues) : {r}")
    if r[0] in seen:
        sys.exit(f"clé en double : {r[0]}")
    seen.add(r[0])


def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


for col, lang in ((1, "fr"), (2, "en")):
    out = root / "App/Resources" / f"{lang}.lproj"
    out.mkdir(parents=True, exist_ok=True)
    body = "".join(f'"{esc(r[0])}" = "{esc(r[col])}";\n' for r in sorted(rows))
    (out / "Localizable.strings").write_text(body, encoding="utf-8")
print(f"{len(rows)} clés écrites en fr et en")
