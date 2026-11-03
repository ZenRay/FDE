#!/usr/bin/env python3
"""Check matching learning days and local Markdown links in two documents."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


DAY_HEADING = re.compile(r"^##\s+((?:第[零一二三四五六七八九十百\d]+天)|(?:Day\s*\d+))", re.I)
LINK = re.compile(r"(?<!!)\[[^\]]+\]\(\s*(?:<([^>]+)>|([^\s)]+))")


def read_doc(path: Path) -> tuple[list[str], list[tuple[int, str]]]:
    days: list[str] = []
    links: list[tuple[int, str]] = []
    in_fence = False
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if re.match(r"^\s*(```|~~~)", line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        heading = DAY_HEADING.match(line)
        if heading:
            days.append(heading.group(1).replace(" ", "").lower())
        for match in LINK.finditer(line):
            links.append((number, match.group(1) or match.group(2)))
    return days, links


def local_target(source: Path, raw: str) -> Path | None:
    url = urlsplit(raw)
    if url.scheme or url.netloc or raw.startswith("#"):
        return None
    target = unquote(url.path)
    if not target:
        return None
    path = Path(target)
    return path if path.is_absolute() else source.parent / path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path, help="learning plan Markdown")
    parser.add_argument("checks", type=Path, help="outcome checks Markdown")
    args = parser.parse_args()
    errors: list[str] = []
    docs = []
    for path in (args.plan, args.checks):
        if not path.is_file():
            errors.append(f"missing document: {path}")
            continue
        days, links = read_doc(path)
        docs.append((path, days, links))
        if not days:
            errors.append(f"no day headings in {path}")
        if len(days) != len(set(days)):
            errors.append(f"duplicate day headings in {path}: {days}")
        for line, raw in links:
            target = local_target(path, raw)
            if target is not None and not target.exists():
                errors.append(f"broken link: {path}:{line}: {raw}")
    if len(docs) == 2 and docs[0][1] != docs[1][1]:
        errors.append(f"day mismatch: {docs[0][1]} vs {docs[1][1]}")
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(f"OK: {len(docs[0][1])} matching learning days; local links exist")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
