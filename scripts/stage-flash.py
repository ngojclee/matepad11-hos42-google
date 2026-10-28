#!/usr/bin/env python3
"""Build and validate a fastboot staging tree from extracted HarmonyOS 4.2 images.

Usage:
    python stage-flash.py -i work -o stage

`work` is the folder holding the output of extract_updateapp.py, e.g.

    work/base/*.img  work/cust/*.img  work/preload/*.img  work/super.img

What it does:
  * maps every image to the right LUN (0 / 1 / 4)
  * repairs the two names that the 16-byte container field truncates
  * drops non-image entries (SHA256RSA, CRC, *_VERLIST, PACKAGE_TYPE, EFI, PTABLE_*)
  * drops `abl` on purpose (flashing it relocks the bootloader)
  * drops the two ramdisk partitions that do not fit the current layout
  * writes stage\\lun0|lun1|lun4 and prints a size table

The authoritative size check still happens in flash-hos42.ps1, which asks the
bootloader for the real partition size before every write.
"""
import argparse
import os
import shutil
import sys

LUN0 = ["cache", "metadata", "ramdisk", "eng_system", "eng_vendor",
        "vbmeta_system", "vbmeta_vendor", "vbmeta_odm", "vbmeta_cust",
        "vbmeta_hw_product", "preas", "preavs", "patch", "kpatch",
        "version", "super", "preload", "recovery", "recovery_vendor",
        "recovery_vbmeta", "erecovery", "erecovery_vendor", "erecovery_vbmeta"]
LUN1 = ["xbl", "xbl_config"]
LUN4 = ["aop", "tz", "hyp", "modem", "bluetooth", "dsp", "keymaster", "boot",
        "devcfg", "qupfw", "vbmeta", "dtbo", "uefisecapp", "featenabler",
        "apdp", "storsec"]

PLAN = {0: LUN0, 1: LUN1, 4: LUN4}

# target sizes in MiB on the CN 4.2 layout, for the printed table only
TARGET_MB = {
    "cache": 104, "metadata": 16, "ramdisk": 2, "eng_system": 24, "eng_vendor": 24,
    "vbmeta_system": 1, "vbmeta_vendor": 1, "vbmeta_odm": 1, "vbmeta_cust": 1,
    "vbmeta_hw_product": 1, "preas": 296, "preavs": 32, "patch": 256, "kpatch": 4,
    "version": 576, "super": 7336, "preload": 1400, "recovery": 96,
    "recovery_vendor": 24, "recovery_vbmeta": 1, "erecovery": 96,
    "erecovery_vendor": 24, "erecovery_vbmeta": 1,
    "xbl": 3.5, "xbl_config": 0.25,
    "aop": 0.5, "tz": 4, "hyp": 0.5, "modem": 188, "bluetooth": 1, "dsp": 64,
    "keymaster": 1, "boot": 96, "devcfg": 1, "qupfw": 0.06, "vbmeta": 1,
    "dtbo": 24, "uefisecapp": 2, "featenabler": 0.12, "apdp": 0.25, "storsec": 0.12,
}

RENAME = {"vbmeta_hw_produc": "vbmeta_hw_product"}

# deliberately not flashed
SKIP = {
    "abl",                 # stock ABL -> would relock the bootloader
    "recovery_ramdisk",    # 36 MiB image, 32 MiB partition on the HOS-2 layout
    "erecovery_ramdisk",
    "erecovery_ramdis",    # truncated name of the same thing
    "gpt_main0", "gpt_backup0", "gpt_main1", "gpt_backup1", "gpt_main4", "gpt_backup4",
}


def collect(root):
    found = {}
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            if not name.lower().endswith(".img"):
                continue
            key = os.path.splitext(name)[0].lower()
            key = RENAME.get(key, key)
            found.setdefault(key, os.path.join(dirpath, name))
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-i", "--input", required=True)
    ap.add_argument("-o", "--output", required=True)
    args = ap.parse_args()

    images = collect(args.input)
    if "super" not in images:
        print("WARNING: no super.img — run sparse.py first (super_part0 + super_part1)")

    if os.path.isdir(args.output):
        shutil.rmtree(args.output)

    rows, problems = [], []
    for lun, parts in PLAN.items():
        outdir = os.path.join(args.output, f"lun{lun}")
        os.makedirs(outdir, exist_ok=True)
        for part in parts:
            src = images.get(part)
            if not src:
                problems.append(f"missing image: {part}")
                rows.append((lun, part, None, None, "MISSING"))
                continue
            size = os.path.getsize(src)
            cap = TARGET_MB.get(part)
            fits = cap is None or size <= cap * 1048576
            if not fits:
                problems.append(f"{part}: {size/1048576:.1f} MiB > {cap} MiB")
            dst = os.path.join(outdir, part + ".img")
            if not os.path.exists(dst):
                os.link(src, dst) if hasattr(os, "link") else shutil.copy2(src, dst)
            rows.append((lun, part, size, cap, "OK" if fits else "TOO BIG"))

    print(f"{'LUN':<5}{'partition':<22}{'image MiB':>11}{'target MiB':>12}  fit")
    for lun, part, size, cap, status in rows:
        s = f"{size/1048576:.1f}" if size is not None else "-"
        c = f"{cap:.2f}" if cap is not None else "-"
        print(f"{lun:<5}{part:<22}{s:>11}{c:>12}  {status}")

    skipped = sorted(k for k in images if k in SKIP)
    if skipped:
        print("\nnot staged on purpose: " + ", ".join(skipped))
    extra = sorted(set(images) - {p for parts in PLAN.values() for p in parts} - SKIP)
    if extra:
        print("ignored non-image entries: " + ", ".join(extra))

    if problems:
        print("\n*** PROBLEMS ***")
        for p in problems:
            print("  -", p)
        return 1
    print(f"\nALL GOOD — staging tree: {os.path.abspath(args.output)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
