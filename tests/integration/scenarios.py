"""Scenarios for run.py, read from scenarios.yaml, and the check sets they
name. A check set gets the Result of a run and returns (description, ok)
pairs: on what the guest wrote to OUT: and on the medium image."""

from pathlib import Path

import yaml


def volume_line(lines, dev):
    """Info lists a device as "FA0 " (3.2) or "FA0:" (3.1, AROS)."""
    name = dev.rstrip(":")
    return next((line for line in lines if line.startswith((name + " ", name + ":"))), "")


def mounted(r):
    return "read/write" in volume_line(r.text("info0.txt").splitlines(), r.dev).lower()


def fat(r, fs):
    """Mounted, the payload read back, smoke passed, a written file read back and on the image."""
    return [
        ("%s mounted read/write" % fs, mounted(r)),
        ("payload read back", r.got() == r.payload),
        ("smoke: seeks, SetFileSize, rename, delete", "PASS: smoke" in r.text("smoke.txt")),
        ("written file reads back", r.back() == r.up),
        ("written file on the image", r.image_file("up.bin") == r.up),
    ]


CHECKS = {"fat": fat}


def load(path):
    data = yaml.safe_load(path.read_text())
    fragments = data["fragments"]
    out = {}
    for name, s in data["scenarios"].items():
        unknown = [f for f in s["steps"] if f not in fragments]
        if unknown or s["checks"] not in CHECKS:
            raise SystemExit("%s: %s: unknown %s" % (path, name, ", ".join(unknown) or s["checks"]))
        sc = dict(s)
        sc["steps"] = "".join(fragments[f] for f in s["steps"])
        fs = "fat12"
        if "layout" in s:
            lay = s["layout"]
            table = {"none": None, "rdb": "rdb"}.get(lay["table"], lay["table"])
            sc["layout"] = (lay["fs"], table, lay["sectors"])
            fs = lay["fs"]
        check, label = CHECKS[s["checks"]], fs.upper()
        sc["checks"] = lambda r, check=check, label=label: check(r, label)
        if "os" in s:
            sc["os"] = tuple(str(o) for o in s["os"])
        out[name] = sc
    return out


SCENARIOS = load(Path(__file__).resolve().parent / "scenarios.yaml")
