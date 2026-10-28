#!/usr/bin/env python3
"""Converts docs/legal/<doc>.<lang>.md into data/legal.json (BBCode for RichTextLabel)."""
import json
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "docs", "legal")


def to_bbcode(md: str) -> str:
    out = []
    for line in md.splitlines():
        if line.startswith("# "):
            out.append("[font_size=30][b]%s[/b][/font_size]" % line[2:])
        elif line.startswith("## "):
            out.append("\n[font_size=22][b]%s[/b][/font_size]" % line[3:])
        elif line.startswith("- "):
            out.append("  • " + line[2:])
        else:
            out.append(line)
    text = "\n".join(out)
    return re.sub(r"\*\*(.+?)\*\*", r"[b]\1[/b]", text)


def main():
    data = {}
    for fn in sorted(os.listdir(SRC)):
        if not fn.endswith(".md"):
            continue
        doc, lang, _ = fn.split(".")
        data.setdefault(doc, {})[lang] = to_bbcode(open(os.path.join(SRC, fn), encoding="utf-8").read())
    with open(os.path.join(ROOT, "data", "legal.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print("legal docs:", ", ".join(sorted(data)))


if __name__ == "__main__":
    main()
