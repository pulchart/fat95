#!/usr/bin/env python3
"""Turn the output of make test-amifuse into a markdown summary: what each suite checks, what each case and scenario means, and its result.

Status: CI helper for the handler-in-the-loop tier. Reads the suites with ast and imports nothing from them.
Run: python3 tests/amifuse_summary.py amifuse.log"""

import argparse
import ast
import re
from pathlib import Path

TESTS = Path(__file__).resolve().parent

IMAGES = {
    "fat12_720": "FAT12, 720 KB floppy",
    "fat12_1440": "FAT12, 1.44 MB floppy",
    "fat16_32m": "FAT16, 32 MB",
    "fat32_128m": "FAT32, 128 MB",
}
SUITE_LEGEND = (
    ("matrix", "create, write, seek, resize, delete, rename and live handles, then remounts"),
    (
        "full",
        "the volume is filled to its last clusters, a write runs into disk full and the volume recovers",
    ),
    ("clean / dirty", "the volume starts cleanly unmounted, or not, as after a crash"),
    (
        "valid / unknown",
        "the FAT32 FSInfo free count is valid, or unknown, so fat95 counts the free clusters itself",
    ),
)
MEDIA_LEGEND = (
    ("remove-write", "the card is pulled during a write"),
    ("write-error", "a write fails with an error while the card stays"),
    ("flush-error", "the flush of the volume fails"),
    ("same", "the same card comes back, and what fat95 kept is still there"),
    ("different", "another card goes in, and nothing buffered for the old card reaches it"),
)

SUITE_RE = re.compile(
    r"^\w+-(fat\d+_\w+)-(matrix|full)-(clean|dirty)-(valid|unknown) (passed|failed)$"
)
MEDIA_RE = re.compile(
    r"^(fat\d+_\w+)-(remove-write|write-error|flush-error)-(same|different) (passed|failed)$"
)
FORMAT_RE = re.compile(r"^format (\S+): ok$")
FAT_CASE_RE = re.compile(r"^(\w+) FAT(\d+)( with \^)?: ok$")
CASE_RE = re.compile(r"^(case_\w+): ok$")


def first_sentence(text):
    text = " ".join((text or "").split())
    end = text.find(". ")
    return text if end < 0 else text[: end + 1]


def docs(name):
    """The module docstring and the docstrings of its functions, read with ast."""
    path = TESTS / name
    if not path.exists():
        return "", {}
    tree = ast.parse(path.read_text())
    functions = {
        node.name: first_sentence(ast.get_docstring(node))
        for node in tree.body
        if isinstance(node, ast.FunctionDef)
    }
    return first_sentence(ast.get_docstring(tree)), functions


def result(word):
    return "passed" if word in ("passed", "ok") else "**failed**"


def table(head, rows):
    out = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    out += ["| " + " | ".join(row) + " |" for row in rows]
    return out


def legend(items):
    return ["", *("- **%s**: %s" % item for item in items)]


def summary(lines):
    suite, media, fmt, other = [], [], [], {}
    fat_suites = [
        ("amifuse_fat_names.py", "Names outside the code page"),
        ("amifuse_full_dir.py", "A directory whose last slot is in use"),
    ]
    loaded = {name: docs(name) for name, _ in fat_suites}
    exfat_doc, exfat_cases = docs("amifuse_exfat.py")
    for line in lines:
        line = line.rstrip()
        if m := SUITE_RE.match(line):
            image, scenario, start, fsinfo, word = m.groups()
            suite.append((IMAGES.get(image, image), scenario, start, fsinfo, result(word)))
        elif m := MEDIA_RE.match(line):
            image, event, back, word = m.groups()
            media.append((IMAGES.get(image, image), event, back, result(word)))
        elif m := FORMAT_RE.match(line):
            fmt.append((IMAGES.get(m.group(1), m.group(1)), result("ok")))
        elif m := FAT_CASE_RE.match(line):
            name, bits, caret = m.groups()
            where = next((n for n, _ in fat_suites if name in loaded[n][1]), fat_suites[-1][0])
            key = "`%s`%s" % (name, " with ^" if caret else "")
            row = other.setdefault(where, {}).setdefault(key, [loaded[where][1].get(name, ""), {}])
            row[1]["FAT" + bits] = result("ok")
        elif m := CASE_RE.match(line):
            name = m.group(1)
            row = other.setdefault("amifuse_exfat.py", {}).setdefault(
                "`%s`" % name, [exfat_cases.get(name, ""), {}]
            )
            row[1]["exFAT"] = result("ok")

    out = ["", "### amifuse"]
    if suite:
        out += ["", "#### Packet matrix", "", docs("amifuse_suite.py")[0], ""]
        out += table(("image", "scenario", "start", "FSInfo", "result"), suite)
        out += legend(SUITE_LEGEND)
    if media:
        out += ["", "#### Media changes", "", docs("amifuse_media.py")[0], ""]
        out += table(("image", "event", "card", "result"), media)
        out += legend(MEDIA_LEGEND)
    if fmt:
        out += ["", "#### Format", "", docs("amifuse_format.py")[0], ""]
        out += table(("image", "result"), fmt)
    titles = dict(fat_suites) | {"amifuse_exfat.py": "exFAT"}
    for name, rows in other.items():
        intro = exfat_doc if name == "amifuse_exfat.py" else loaded[name][0]
        out += ["", "#### " + titles[name], "", intro, ""]
        volumes = sorted({v for _, results in rows.values() for v in results})
        body = [
            (key, what, *(results.get(v, "") for v in volumes))
            for key, (what, results) in rows.items()
        ]
        out += table(("case", "what it checks", *volumes), body)
        if any(key.endswith(" with ^") for key in rows):
            out += legend(
                (
                    (
                        "with ^",
                        "the same case run with ^, the default escape character, instead of %",
                    ),
                )
            )
    return "\n".join(out) + "\n"


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("log", type=Path, help="output of make test-amifuse")
    args = p.parse_args()
    print(summary(args.log.read_text(errors="replace").splitlines()), end="")


if __name__ == "__main__":
    main()
