"""Scenarios for run.py, read from scenarios.yaml, and the check sets they
name. A check set gets the Result of a run and returns (description, ok)
pairs: on what the guest wrote to OUT: and on the medium image."""

from pathlib import Path

import fatnames
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


def names(r, fs):
    """Long names outside the code page show as ^ escapes, and typed escapes, in
    either case, reach those names; Delete of an escaped name leaves a880 alone."""
    files = dict(fatnames.FILES)
    listed = (
        (r.out / "names0.txt").read_bytes().decode("latin-1").split()
        if (r.out / "names0.txt").exists()
        else []
    )
    after = (
        (r.out / "names1.txt").read_bytes().decode("latin-1").split()
        if (r.out / "names1.txt").exists()
        else []
    )
    image = fatnames.Fat16(r.image, r.start * 512).files()
    typed = {
        "type_a.txt": "a\u0100.txt",
        "type_r.txt": "r\u4e2d.txt",
        "type_c.txt": "c\U0001f600.txt",
        "type_p.txt": "p^880.txt",
    }
    out = [("%s mounted read/write" % fs, mounted(r))]
    out.append(
        ("every name listed with its escapes", all(fatnames.shown(n) in listed for n in files))
    )
    out += [("Type of %s" % fatnames.shown(n), r._bytes(t) == files[n]) for t, n in typed.items()]
    out += [
        ("Copy made b^880.txt", image.get("b\u0100.txt") == files["a\u0100.txt"]),
        (
            "Rename made s^D72Q.txt",
            image.get("s\u4e2d.txt") == files["r\u4e2d.txt"] and "r\u4e2d.txt" not in image,
        ),
        (
            "Delete a^880.txt removed only that file",
            "a\u0100.txt" not in image and image.get("a880.txt") == files["a880.txt"],
        ),
        ("Echo created new^880.txt", (image.get("new\u0100.txt") or b"").startswith(b"new")),
        (
            "the new names listed",
            all(n in after for n in ("b^880.txt", "s^D72Q.txt", "new^880.txt"))
            and "a^880.txt" not in after,
        ),
        ("%s image clean" % fs, r.image_free() is not None),
    ]
    return out


LOCALE = Path(__file__).resolve().parents[2] / "dist/locale"


def rc_text(r, name, rc):
    """The output of a command and the rc line the step appends after it."""
    text = r.text(name)
    return text, "rc %d" % rc in text.splitlines()


def install95(r, fs):
    """Every language goes into the handler and reads back the same; the
    errors name their cause and return 10; a handler set to czech lists the
    czech name in its code page and creates one typed in it."""
    out = []
    for lang in sorted(p.name for p in LOCALE.iterdir()):
        wrote = rc_text(r, "iw_%s.txt" % lang, 0)[1] and rc_text(r, "irr_%s.txt" % lang, 0)[1]
        back = r._bytes("ir_" + lang)
        same = back is not None and fatnames.locale_sections(back) == fatnames.locale_sections(
            (LOCALE / lang).read_bytes()
        )
        out.append(("%s written and read back the same" % lang, wrote and same))
    for name, text in (
        ("e_noargs.txt", "required argument missing"),
        ("e_usage.txt", "usage: install95 WRITE|READ <language> [HANDLER <file>]"),
        ("e_nolang.txt", "cannot read the language file."),
        ("e_nohandler.txt", 'file "RAM:missing" not found.'),
        ("e_protected.txt", 'cannot write "FA0:ro".'),
        ("e_same.txt", 'the language file cannot be "RAM:fat95".'),
    ):
        got, rc = rc_text(r, name, 10)
        out.append(("%s: %s, rc 10" % (name[2:-4], text), rc and text in got))
    table = fatnames.code_page((LOCALE / "cestina").read_bytes())
    listed = r._bytes("names_cz.txt") or b""
    czech = "p\u0159\u00edli\u0161.txt"
    image = fatnames.Fat16(r.image, r.start * 512).files()
    out += [
        ("%s mounted read/write by the czech handler" % fs, mounted(r)),
        (
            "names listed in the czech code page",
            all(
                fatnames.shown(n, table=table).encode("latin-1") in listed.split()
                for n, _ in fatnames.FILES
            ),
        ),
        (
            "a name typed in it created on the image",
            image.get("x" + czech) == dict(fatnames.FILES)[czech],
        ),
        ("%s image clean" % fs, r.image_free() is not None),
    ]
    return out


def listed(r, name="names0.txt"):
    p = r.out / name
    return p.read_bytes().decode("latin-1").split() if p.exists() else []


def names_pct(r, fs):
    """Control +n%: escapes with %, as fat95 4.2 showed them; ^ is a plain character. AmigaOS Type
    reads a%880.txt as a pattern that finds a880.txt, so there the name needs a'%880.txt."""
    files = dict(fatnames.FILES)
    return [
        ("%s mounted read/write" % fs, mounted(r)),
        (
            "every name listed with % escapes",
            all(fatnames.shown(n, "%") in listed(r) for n in files),
        ),
        (
            "a%880.txt reached as typed, or with ' where Type reads % as a pattern",
            r._bytes("type_a.txt") == files["a\u0100.txt"]
            or (
                r._bytes("type_a.txt") == files["a880.txt"]
                and r._bytes("type_q.txt") == files["a\u0100.txt"]
            ),
        ),
        ("Type of p^880.txt", r._bytes("type_p.txt") == files["p^880.txt"]),
    ]


def names_off(r, fs):
    """Control -n: a character outside the code page shows as _, an emoji as one _; ^ is a plain character."""
    files = dict(fatnames.FILES)
    off = ["".join(c if ord(c) < 0x100 else "_" for c in n) for n in files]
    return [
        ("%s mounted read/write" % fs, mounted(r)),
        ("every name listed with _", all(n in listed(r) for n in off)),
        ("Type of p^880.txt", r._bytes("type_p.txt") == files["p^880.txt"]),
    ]


def installer(r, fs):
    """Language leaves another fat95 version as it was; Install puts this fat95
    for the CPU in place with the execute bit, ptable.library 3.0, lsptres and
    the default language."""
    tier = "68000" if "-a600" in str(r.d) else "68020"
    old = (r.out / "old_fat95").read_bytes() if (r.out / "old_fat95").exists() else None
    back = r._bytes("lang_after")
    after = r.text("after.txt")
    return [
        ("Language finished", "rc 0" in r.text("language_rc.txt")),
        ("Language left fat95 4.2 as it was", old is not None and r._bytes("fat95_mid") == old),
        ("Install finished", "rc 0" in r.text("install_rc.txt")),
        ("L:fat95 is fat95 5.0 for %s" % tier, "fat95 5.0" in after and "[%s]" % tier in after),
        ("L:fat95 has the execute bit", r.text("prot.txt").strip()[-2:-1] == "e"),  # hsparwed
        ("LIBS:ptable.library is 3.0", "ptable.library 3.0" in r.text("ptable.txt")),
        ("C:lsptres copied", "lsptres" in r.text("lsptres.txt")),
        (
            "the language is english",
            back is not None
            and fatnames.locale_sections(back)
            == fatnames.locale_sections((LOCALE / "english").read_bytes()),
        ),
    ]


CHECKS = {
    "installer": installer,
    "fat": fat,
    "stress": stress,
    "names": names,
    "names_pct": names_pct,
    "names_off": names_off,
    "install95": install95,
}


def load(path):
    data = yaml.safe_load(path.read_text())
    fragments = data["fragments"]
    out = {}
    for name, s in data["scenarios"].items():
        unknown = [f for f in s["steps"] if f not in fragments]
        if unknown or s["checks"] not in CHECKS:
            raise SystemExit("%s: %s: unknown %s" % (path, name, ", ".join(unknown) or s["checks"]))
        sc = dict(s)
        langs = sorted(p.name for p in LOCALE.iterdir()) if LOCALE.is_dir() else []
        steps = "".join(
            "".join(fragments[f].replace("{lang}", lang) for lang in langs)
            if "{lang}" in fragments[f]
            else fragments[f]
            for f in s["steps"]
        )
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
