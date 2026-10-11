#!/usr/bin/env python3
"""Assemble the installed skins: desktop/skins/<id>/ -> <out>/<id>/ plus index.txt.

Each skin directory holds a skin.cfg, vector art (*.vec) and bitmaps. Bitmaps
may be PNG (converted to VBM1 here, as the desktop cannot decode PNG) or already
.vbm. A cfg line that names `foo.png` is rewritten to `foo.vbm`.
"""
import os
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(__file__))
from png2vbm import png_to_vbm  # noqa: E402

ID_RE = re.compile(r"^[a-z0-9_-]{1,32}$")


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    index = []
    for sid in sorted(os.listdir(src)):
        sdir = os.path.join(src, sid)
        cfg = os.path.join(sdir, "skin.cfg")
        if not ID_RE.match(sid) or not os.path.isfile(cfg):
            continue
        dest = os.path.join(out, sid)
        os.makedirs(dest, exist_ok=True)
        name = sid
        text = open(cfg, encoding="utf-8").read()
        for line in text.splitlines():
            if line.startswith("name="):
                name = line[5:].strip()
        text = re.sub(r"\b([A-Za-z0-9_.-]+)\.png\b", r"\1.vbm", text)
        with open(os.path.join(dest, "skin.cfg"), "w", encoding="utf-8") as f:
            f.write(text)
        ok = True
        for f in sorted(os.listdir(sdir)):
            path = os.path.join(sdir, f)
            if f.endswith(".png"):
                try:
                    png_to_vbm(path, os.path.join(dest, f[:-4] + ".vbm"))
                except ImportError:
                    print(f"skin {sid}: Pillow missing, skipping {f}", file=sys.stderr)
                    ok = False
            elif f.endswith(".vec") or f.endswith(".vbm"):
                shutil.copy(path, os.path.join(dest, f))
        if ok:
            index.append(f"{sid} {name}")
    with open(os.path.join(out, "index.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(index) + ("\n" if index else ""))


if __name__ == "__main__":
    main()
