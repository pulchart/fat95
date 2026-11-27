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


def stress(r, fs):
    """Every FileSystemStressTest run validated and removed its files, the
    directory is empty, the image is clean and the handler's free count
    matches the image."""
    out = [("%s mounted read/write" % fs, mounted(r))]
    steps = r.text("steps")
    for name in ("st_a", "st_b", "st_c", "st_f"):
        if "OUT:%s.txt" % name not in steps:
            continue
        log = r.text(name + ".txt")
        bad = [line for line in log.splitlines() if "ailed" in line or "rror" in line]
        rc = "rc 0" in log or '"rc $RC" >>OUT:%s.txt' % name not in steps  # Run gives no rc
        rc = rc and "Total processing time" in log  # every iteration ran
        out.append(
            (
                "%s: files validated and removed" % name,
                "Successfully removed" in log and rc and not bad,
            )
        )
    listing = r.text("st_list.txt")
    out.append(("stress directory empty at the end", "is empty" in listing))
    free = r.image_free()
    out.append(("%s image clean" % fs, free is not None))
    out.append(
        ("handler free clusters match the image", free is not None and r.handler_free() == free)
    )
    return out


CHECKS = {"fat": fat, "stress": stress}


def load(path):
    data = yaml.safe_load(path.read_text())
    fragments = data["fragments"]
    out = {}
    for name, s in data["scenarios"].items():
        unknown = [f for f in s["steps"] if f not in fragments]
        if unknown or s["checks"] not in CHECKS:
            raise SystemExit("%s: %s: unknown %s" % (path, name, ", ".join(unknown) or s["checks"]))
        sc = dict(s)
        steps = "".join(fragments[f] for f in s["steps"])
        for key, value in s.get("stress", {}).items():
            steps = steps.replace("{st_%s}" % key, str(value))
        sc["steps"] = steps
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
