#!/usr/bin/env python3
"""fat95 under AmigaOS and AROS in FS-UAE (A1200): PC floppies through
mfm.device and IDE disks with FAT partitions.

    run.py [--config FILE] [--os NAME ...] [--scenario NAME ...] [--list] [--work DIR]

Preparation builds the boot medium per OS: an AmigaOS boot disk from the OS
disks named in the config, or a copy of an AROS system directory, with fat95,
dd, lsfsres and the test tools (smoke from make smoke) on it. Each scenario gets its own medium image,
mountlist and steps; the guest writes its findings to the host directory OUT:,
and the host checks them and the image. Exit 0 when every scenario that ran
passes; an OS whose files are missing is skipped.
"""

import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import yaml
from scenarios import SCENARIOS

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent  # relative paths in the config start here
BOOT_LIMIT = 60  # seconds to the first line in OUT:log.txt
PART_START = 2048

# the repository's own builds, used unless the config names others
BUILDS = {
    "fat95": "dist/l/68020/fat95",
    "dd": "dist/c/dd",
    "lsfsres": "dist/c/lsfsres",
    "debug95": "dist/c/debug95",
}
PATH_KEYS = ("fat95", "dd", "lsfsres", "debug95", "ptable", "work")
OS_PATH_KEYS = ("kickstart", "kickstart_ext", "commands_adf", "workbench_adf", "system_dir")
SMOKE = ROOT / "build/tools/smoke"  # make smoke

sys.path.insert(0, str(ROOT / "tools"))
import parse_debug95  # noqa: E402

COMMANDS = ["Assign", "Copy", "Delete", "DiskChange", "Execute", "Info", "List",
            "MakeDir", "Mount", "SetPatch", "Version", "Wait"]  # fmt: skip

# pr_WindowPtr -1 for the shell process: a missing volume is an error, not a
# requester that waits forever
NOREQ = (
    "\tmove.l\t4.w,a6\n\tsub.l\ta1,a1\n\tjsr\t-294(a6)\n\tmove.l\td0,a0\n"
    "\tmoveq\t#-1,d0\n\tmove.l\td0,184(a0)\n\tmoveq\t#0,d0\n\trts\n"
)

STARTUP = """SetPatch >NIL:
FailAt 200
MakeDir RAM:T RAM:ENV
Assign >NIL: ENV: RAM:ENV
Assign >NIL: T: RAM:T
Echo "start" >OUT:log.txt
noreq
Execute OUT:steps
Echo "DONE" >OUT:done
"""

MOUNTLIST = """{name}:
FileSystem = L:fat95
Device = {device}
Unit = {unit}
Flags = 0
LowCyl = 0
HighCyl = {highcyl}
Surfaces = {surfaces}
BlocksPerTrack = {bpt}
BlockSize = 512
Buffers = 50
BufMemType = 1
BootPri = 0
Stacksize = {stack}
Priority = 5
GlobVec = -1
Mask = 0xfffffffe
MaxTransfer = {max_transfer:#x}
DosType = {dostype}
#
"""


def sh(*a, **k):
    return subprocess.run([str(x) for x in a], check=True, capture_output=True, **k)


def adf_read(adf, path, dest):
    """Read path from an ADF; a compressed update file (name.Z) is unpacked."""
    for name in (path, path + ".Z"):
        r = subprocess.run(["xdftool", str(adf), "read", name, str(dest)], capture_output=True)
        if r.returncode == 0 and dest.exists():
            if name.endswith(".Z"):
                data = subprocess.run(["gzip", "-dc", str(dest)], capture_output=True, check=True)
                dest.write_bytes(data.stdout)
            return True
    return False


def prepare(cfg, osname, osc, work):
    """The boot medium for one OS; returns the FS-UAE lines that attach it."""
    prep = work / osname / "boot"
    prep.mkdir(parents=True)
    s = prep / "noreq.s"
    s.write_text(NOREQ)
    sh(cfg["vasm"], "-quiet", "-Fhunkexe", "-o", prep / "noreq", s)
    payload = [
        (prep / "noreq", "C/noreq"),
        (SMOKE, "C/smoke"),
        (cfg["dd"], "C/dd"),
        (cfg["lsfsres"], "C/lsfsres"),
        (cfg["fat95"], "L/fat95"),
    ]
    if osc.get("ptable", True):  # fat95 reads partition tables through it
        payload.append((cfg["ptable"], "Libs/ptable.library"))
    if "system_dir" in osc:  # AROS: boot from a directory
        sysdir = prep / "sys"
        shutil.copytree(osc["system_dir"], sysdir, symlinks=True)
        subprocess.run(["chmod", "-R", "u+w", str(sysdir)], check=True)  # an ISO tree is read-only
        for src, dest in payload:
            shutil.copyfile(src, sysdir / dest)
        (sysdir / "S/Startup-Sequence").write_text(STARTUP.replace("SetPatch >NIL:\n", ""))
        return [
            "hard_drive_2 = %s" % sysdir,
            "hard_drive_2_label = Boot",
            "hard_drive_2_priority = 10",
        ]
    adf = prep / "boot.adf"
    sh("xdftool", adf, "create", "+", "format", "TestBoot", "DOS3", "+", "boot", "install")
    for d in ("C", "S", "L", "Libs", "Devs"):
        sh("xdftool", adf, "makedir", d)
    for cmd in COMMANDS:
        if not any(adf_read(a, "C/" + cmd, prep / cmd) for a in osc["commands_adf"]):
            sys.exit("C/%s is on none of %s" % (cmd, ", ".join(map(str, osc["commands_adf"]))))
        sh("xdftool", adf, "write", prep / cmd, "C/" + cmd)
    if adf_read(osc["workbench_adf"], "Devs/mfm.device", prep / "mfm.device"):
        payload.append((prep / "mfm.device", "Devs/mfm.device"))
    for src, dest in payload:
        sh("xdftool", adf, "write", src, dest)
    (prep / "startup").write_text(STARTUP)
    sh("xdftool", adf, "write", prep / "startup", "S/Startup-Sequence")
    return ["floppy_drive_0 = %s" % adf, "writable_floppy_images = 0"]


def fat_volume(path, fs, sectors, payload):
    """A FAT volume image (mtools) with payload.bin on it."""
    path.unlink(missing_ok=True)
    bits = fs[3:]
    extra = ["-s", "1"] if bits == "32" else []
    sh("mkfs.fat", "-C", "-F", bits, *extra, "-n", fs.upper(), path, sectors // 2)
    tmp = path.with_suffix(".payload")
    tmp.write_bytes(payload)
    sh("mcopy", "-i", path, tmp, "::payload.bin")
    tmp.unlink()


def medium(d, sc, payload, cfg, osc):
    """The medium image, the volume start and the mountlist fields for it
    (None when the OS mounts the volume from an RDB)."""
    if sc["medium"] == "floppy":
        img = d / "pc.img"
        sh("mkfs.fat", "-C", "-F", "12", "-f", "2", "-r", "112", "-s", "2", "-S", "512",
           "-g", "2/9", "-n", "FAT12", img, 720)  # fmt: skip
        tmp = d / "payload.tmp"
        tmp.write_bytes(payload)
        sh("mcopy", "-i", img, tmp, "::payload.bin")
        tmp.unlink()
        return (
            img,
            0,
            dict(device="mfm.device", unit=1, highcyl=79, surfaces=2, bpt=9, dostype="0x46415400"),
        )
    fs, mbrtype, sectors = sc["layout"]
    hdf = d / "disk.hdf"
    if mbrtype == "rdb":  # fat95 in the RDB; the OS mounts FA0 itself
        transfer = ["max_transfer=%d" % osc["max_transfer"]] if "max_transfer" in osc else []
        sh("rdbtool", "-f", hdf, "create", "size=%d" % ((sectors + 256) * 512), "+", "init", "rdb_cyls=8", "+",
           "fsadd", cfg["fat95"], "dostype=0x464154FF", "version=99.0",
           "stack_size=%d" % osc.get("stack", 8192), "+",
           "add", "name=FA0", "size=100%", "dostype=0x464154FF", "bs=512", "automount=1", *transfer)  # fmt: skip
        info = sh("rdbtool", hdf, "list", text=True).stdout
        part = next(line.split() for line in info.splitlines() if line.startswith("Partition: #0"))
        cyl_blks = int(info.split("cyl_blks=")[1].split()[0])
        start, blocks = int(part[3]) * cyl_blks, int(part[5])
        vol = d / "part.img"
        fat_volume(vol, fs, blocks, payload)
        sh(
            "dd",
            "if=%s" % vol,
            "of=%s" % hdf,
            "bs=512",
            "seek=%d" % start,
            "conv=notrunc,sparse",
            "status=none",
        )
        vol.unlink()
        return hdf, start, None
    if mbrtype is None:  # superfloppy: the volume starts at block 0
        fat_volume(hdf, fs, sectors, payload)
        # an unpartitioned medium is as large as the mountlist says
        return hdf, 0, dict(highcyl=sectors - 1, surfaces=1, bpt=1, dostype="0x464154FF")
    with hdf.open("wb") as f:
        f.truncate((PART_START + sectors) * 512)
    table = "label: dos\nstart=%d, size=%d, type=%x\n" % (PART_START, sectors, mbrtype)
    subprocess.run(
        ["sfdisk", "-q", str(hdf)], input=table, text=True, check=True, capture_output=True
    )
    part = d / "part.img"
    fat_volume(part, fs, sectors, payload)
    sh("dd", "if=%s" % part, "of=%s" % hdf, "bs=1M", "seek=%d" % (PART_START // 2048), "conv=notrunc,sparse",
       "status=none")  # fmt: skip
    part.unlink()
    return hdf, PART_START, dict(highcyl=0, surfaces=1, bpt=1, dostype="0x464154FF")


def stop(p):
    for sig in (15, 9):  # FS-UAE can outlive SIGTERM once the guest hangs
        try:
            os.killpg(p.pid, sig)
        except ProcessLookupError:
            break
        time.sleep(3)
    p.wait()


class Result:
    def __init__(self, cfg, d, image, start, dev, payload, up):
        self.cfg, self.d, self.out, self.image, self.start, self.dev = (
            cfg,
            d,
            d / "out",
            image,
            start,
            dev,
        )
        self.payload, self.up = payload, up

    def text(self, name):
        p = self.out / name
        return p.read_text(errors="replace") if p.exists() else ""

    def _bytes(self, name):
        p = self.out / name
        return p.read_bytes() if p.exists() else None

    def got(self):
        return self._bytes("got0.bin")

    def back(self):
        return self._bytes("back0.bin")

    def image_file(self, name):
        r = subprocess.run(["mcopy", "-n", "-i", "%s@@%d" % (self.image, self.start * 512), "::" + name, "-"],
                           capture_output=True, env=dict(os.environ, MTOOLS_SKIP_CHECK="1"))  # fmt: skip
        return r.stdout if r.returncode == 0 else None


def emulate(cfg, d, cfgfile, limit, name):
    """Run FS-UAE until the guest writes OUT:done or the limit passes. A start
    that dies or shows no sign of the guest by BOOT_LIMIT is tried once more:
    FS-UAE and Xvfb now and then fail to come up. Returns (in time, seconds)."""
    out = d / "out"
    env = dict(
        os.environ, XDG_RUNTIME_DIR=str(d / "xdg"), SDL_VIDEODRIVER="x11", SDL_AUDIODRIVER="dummy"
    )
    env.pop("WAYLAND_DISPLAY", None)
    for attempt in (1, 2):
        with (d / "fsuae.log").open("a") as emu:
            p = subprocess.Popen(["xvfb-run", "-a", cfg["fsuae"], str(cfgfile)], env=env, stdout=emu,
                                 stderr=subprocess.STDOUT, start_new_session=True)  # fmt: skip
            t0 = time.monotonic()
            try:
                while (
                    time.monotonic() - t0 < limit
                    and p.poll() is None
                    and not (out / "done").exists()
                ):
                    if time.monotonic() - t0 > BOOT_LIMIT and not (out / "log.txt").exists():
                        break
                    time.sleep(1)
                took = time.monotonic() - t0
                in_time = (out / "done").exists() and took <= limit
                if in_time:
                    time.sleep(1)  # let the last host write land
            finally:
                stop(p)
        if (out / "log.txt").exists():
            return in_time, took
        if attempt == 1:
            print("  %s: the guest did not start, starting FS-UAE again" % name)
    return False, took


def run(cfg, osname, osc, boot, work, name, sc):
    d = work / osname / name
    for sub in ("out", "xdg", "base"):
        (d / sub).mkdir(parents=True)
    out = d / "out"
    payload, up = os.urandom(200000), os.urandom(70000)
    image, start, ml = medium(d, sc, payload, cfg, osc)
    dev = "MS1:" if sc["medium"] == "floppy" else "FA0:"
    if ml is None:  # the OS mounts it from the RDB
        ml = dict(device=osc.get("ide_device", "scsi.device"), unit=osc.get("ide_unit", 0))
    else:
        ml.setdefault("device", osc.get("ide_device", "scsi.device"))
        ml.setdefault("unit", osc.get("ide_unit", 0))
        mountlist = MOUNTLIST.format(name=dev[:-1], stack=osc.get("stack", 8192),
                                     max_transfer=osc.get("max_transfer", 0x20000), **ml)  # fmt: skip
        (out / "mountlist").write_text(mountlist)
    (out / "up.bin").write_bytes(up)
    if cfg.get("debug95") and Path(cfg["debug95"]).exists():
        shutil.copyfile(cfg["debug95"], out / "debug95")
    steps = sc["steps"].format(dev=dev, wait=cfg["wait"], device=ml["device"], unit=ml["unit"],
                               copy=osc.get("copy", "Copy"))  # fmt: skip
    (out / "steps").write_text(steps)
    if sc["medium"] == "floppy":
        attach = [
            "floppy_drive_1 = %s" % image,
            "writable_floppy_images = 1",
            "floppy_drive_count = 2",
        ]
    else:  # a whole disk: type hdf would wrap it in a made-up RDB
        attach = ["hard_drive_1 = %s" % image, "hard_drive_1_type = rdb",
                  "hard_drive_1_controller = %s" % osc.get("ide_controller", "ide0")]  # fmt: skip
    serial = d / "serial.txt"
    serial.touch()
    rom = str(osc["kickstart"])
    ext = osc.get("kickstart_ext") or (rom[:-2] + "E0" if rom.endswith(".F8") else None)
    cpu = osc.get("cpu", "68020")
    speed = []
    if sc.get("fast"):  # sizes and contents, not timing: 68040 with JIT
        cpu, speed = (
            "68040",
            ["jit_compiler = 1", "uae_cachesize = 16384", "uae_cpu_compatible = false"],
        )
    boot_lines = [
        b for b in boot if not (sc["medium"] == "floppy" and b.startswith("writable_floppy_images"))
    ]
    lines = (
        ["[fs-uae]", "amiga_model = A1200", "cpu = %s" % cpu, "chip_memory = 2048",
         "fast_memory = %d" % osc.get("fast_memory", 8192), "kickstart_file = %s" % rom]
        + (["kickstart_ext_file = %s" % ext] if ext else [])
        + boot_lines + attach + list(osc.get("fsuae", [])) + speed
        + ["hard_drive_0 = %s" % out, "hard_drive_0_label = OUT", "hard_drive_0_priority = -128",
           "serial_port = %s" % serial, "joystick_port_1 = none", "uae_cpu_speed = max", "floppy_drive_speed = 800",
           "fullscreen = 0", "base_dir = %s" % (d / "base"), ""]
    )  # fmt: skip
    cfgfile = d / "run.fs-uae"
    cfgfile.write_text("\n".join(lines))
    in_time, took = emulate(cfg, d, cfgfile, sc.get("limit", cfg["limit"]), name)
    r = Result(cfg, d, image, start, dev, payload, up)
    checks = [("finished in time", in_time), *sc["checks"](r)]
    print("== %s %s: %s" % (osname, name, sc["doc"]))
    for what, ok in checks:
        print("  %-48s %s" % (what, "ok" if ok else "FAIL"))
    passed = all(ok for _, ok in checks)
    if (out / "debug95.dump").exists():
        state = handler_state(out / "debug95.dump")
        (d / "state.txt").write_text(state)
        if not passed:
            print("".join("    " + line for line in state.splitlines(True)), end="")
    print("  %s in %.0f s, %s" % ("PASS" if passed else "FAIL", took, d))
    return passed


def handler_state(dump):
    """The parse_debug95.py summary of a dump the guest wrote; never fails the run."""
    try:
        d = parse_debug95.Dump(dump, parse_debug95.Layout(parse_debug95.VARS))
        lines = ["warning: " + w for w in d.warnings()] + parse_debug95.summary_lines(d)
    except (Exception, SystemExit) as e:
        return "no summary of %s: %s\n" % (dump.name, e)
    return "\n".join(lines) + "\n"


def resolve(value):
    """A config path: absolute as given, relative from the repository root."""
    if isinstance(value, list):
        return [resolve(v) for v in value]
    p = Path(value).expanduser()
    return p if p.is_absolute() else ROOT / p


def load_config(path):
    cfg = {
        "fsuae": "fs-uae",
        "vasm": "vasmm68k_mot",
        "wait": 5,
        "limit": 240,
        "work": "build/integration",
    }
    cfg.update(BUILDS)
    cfg.update(yaml.safe_load(path.read_text()) or {})
    missing = [k for k in ("os", "ptable") if k not in cfg]
    for name, osc in (cfg.get("os") or {}).items():
        need = (
            ("kickstart", "system_dir")
            if "system_dir" in osc
            else ("kickstart", "commands_adf", "workbench_adf")
        )
        missing += ["os %s: %s" % (name, k) for k in need if k not in osc]
    if missing:
        sys.exit("%s lacks %s" % (path, ", ".join(missing)))
    for k in PATH_KEYS:
        cfg[k] = resolve(cfg[k])
    for osc in cfg["os"].values():
        if isinstance(osc.get("commands_adf"), str):
            osc["commands_adf"] = [osc["commands_adf"]]
        for k in OS_PATH_KEYS:
            if k in osc:
                osc[k] = resolve(osc[k])
    return cfg


def os_missing(osc):
    """The OS files of a profile that are not there."""
    paths = [
        osc[k] for k in ("kickstart", "kickstart_ext", "workbench_adf", "system_dir") if k in osc
    ]
    return [p for p in paths + osc.get("commands_adf", []) if not p.exists()]


def shown(p):
    """A path as short as the config wrote it."""
    try:
        return os.path.relpath(p, ROOT) if p.is_relative_to(ROOT.parent) else str(p)
    except ValueError:
        return str(p)


def main():
    sys.stdout.reconfigure(line_buffering=True)  # progress shows up in a log file
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument(
        "--config", type=Path, default=Path(os.environ.get("FAT95_IT_CONFIG", HERE / "config.yaml"))
    )
    ap.add_argument("--os", action="append", help="run on these configured OSes only (repeatable)")
    ap.add_argument(
        "--scenario", action="append", choices=sorted(SCENARIOS), help="run only these (repeatable)"
    )
    ap.add_argument("--list", action="store_true", help="list the scenarios and exit")
    ap.add_argument(
        "--work",
        type=Path,
        help="new directory for the run (default: a new one under the config's work)",
    )
    a = ap.parse_args()
    if a.list:
        for name, s in SCENARIOS.items():
            print("%-15s %-28s %s" % (name, ",".join(s.get("os", ("all",))), s["doc"]))
        return
    cfg = load_config(a.config)
    builds = [cfg[k] for k in ("fat95", "dd", "lsfsres", "ptable") if not cfg[k].exists()]
    builds += [SMOKE] if not SMOKE.exists() else []
    if builds:
        sys.exit("missing builds: %s" % ", ".join(map(shown, builds)))
    oses = a.os or list(cfg["os"])
    unknown = [o for o in oses if o not in cfg["os"]]
    if unknown:
        sys.exit("not in the config: %s" % ", ".join(unknown))
    names = a.scenario or list(SCENARIOS)
    plan, skipped = [], []
    print("plan:")
    for osname in oses:
        osc = cfg["os"][osname]
        todo = [n for n in names if osname in SCENARIOS[n].get("os", (osname,))]
        gone = os_missing(osc)
        if gone:
            skipped.append(osname)
            print("  %-13s skip: %s not found" % (osname, ", ".join(map(shown, gone))))
        elif todo:
            plan.append((osname, osc, todo))
            print("  %-13s %s" % (osname, " ".join(todo)))
    work = (a.work or cfg["work"] / time.strftime("fat95-it-%Y%m%d-%H%M%S")).resolve()
    if work.exists():
        sys.exit("%s exists; give a new --work directory" % work)
    work.mkdir(parents=True)
    failed, total = [], 0
    for osname, osc, todo in plan:
        boot = prepare(cfg, osname, osc, work)
        for n in todo:
            total += 1
            if not run(cfg, osname, osc, boot, work, n, SCENARIOS[n]):
                failed.append("%s %s" % (osname, n))
    print(
        "%d/%d scenarios passed%s%s"
        % (
            total - len(failed),
            total,
            "; failed: " + ", ".join(failed) if failed else "",
            "; skipped: " + ", ".join(skipped) if skipped else "",
        )
    )
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
