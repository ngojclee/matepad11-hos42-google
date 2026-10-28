#!/usr/bin/env python3
"""Huawei UPDATE.APP container parser / extractor.

Usage:
    python extract_updateapp.py update_full_base.zip --list
    python extract_updateapp.py update_full_base.zip -o work/base
    python extract_updateapp.py UPDATE.APP             -o work/base

Format notes (this is the part everybody gets wrong):
  * every entry starts with the magic 55 AA 5A A5
  * +0x04 u32  header length  == offset from the magic to the payload
         (varies per entry: 98, 126, 12386, 49250, 2030938 ... do NOT clamp it)
  * +0x08 u32  unknown (1)
  * +0x0C u64  hardware id ("HW7x27" + 0xFFFF)
  * +0x14 u32  sequence
  * +0x18 u32  payload size
  * +0x1C 16B  date  "2024.05.28"
  * +0x2C 16B  time  "16.28.37"
  * +0x3C 16B  type  (partition name, TRUNCATED TO 16 CHARS)
  * payload at magic + header length, next entry = payload + size (4-byte aligned)

Because of the 16-char truncation `vbmeta_hw_product` shows up as `vbmeta_hw_produc`
and `erecovery_ramdisk` as `erecovery_ramdis` — fix the names before flashing.
"""
import argparse
import os
import re
import struct
import sys
import zipfile

MAGIC = b"\x55\xAA\x5A\xA5"
ALIGN = 4
DATE_RE = re.compile(r"^\d{4}\.\d{2}\.\d{2}$")


def iter_entries(fh, total):
    """Yield parsed entries from an open binary file object."""
    pos = 0
    while pos < total - 24:
        fh.seek(pos)
        buf = fh.read(1 << 16)
        if not buf:
            break
        idx = buf.find(MAGIC)
        if idx < 0:
            pos += max(1, len(buf) - 3)
            continue
        start = pos + idx
        fh.seek(start)
        if fh.read(4) != MAGIC:
            pos = start + 4
            continue
        raw = fh.read(94)
        if len(raw) < 94:
            break
        hdr, _unk, _hw, _seq, size = struct.unpack("<LLQLL", raw[:24])
        date = raw[24:40].decode("ascii", "replace").strip("\x00")
        if not DATE_RE.match(date) or size > total or hdr < 94:
            pos = start + 4
            continue
        payload = start + hdr
        end = payload + size
        pad = (ALIGN - end % ALIGN) % ALIGN
        yield dict(
            start=start,
            header=hdr,
            size=size,
            date=date,
            time=raw[40:56].decode("ascii", "replace").strip("\x00"),
            type=raw[56:72].decode("ascii", "replace").strip("\x00"),
            payload=payload,
        )
        pos = end + pad


def open_source(path):
    """Return (file object, size, closer). Accepts a .zip or a raw .APP."""
    if zipfile.is_zipfile(path):
        zf = zipfile.ZipFile(path)
        name = next((n for n in zf.namelist() if n.upper().endswith(".APP")), None)
        if not name:
            raise SystemExit(f"no .APP entry inside {path}")
        info = zf.getinfo(name)
        return zf.open(name), info.file_size, zf
    return open(path, "rb"), os.path.getsize(path), None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", help=".zip package or raw UPDATE.APP")
    ap.add_argument("-o", "--out", help="output directory")
    ap.add_argument("--list", action="store_true", help="only list entries")
    args = ap.parse_args()

    fh, total, closer = open_source(args.source)
    try:
        entries = list(iter_entries(fh, total))
        print(f"{args.source}: {total} bytes, {len(entries)} entries")
        print(f"{'type':<24}{'size':>14}{'MB':>10}  header")
        for e in entries:
            print(f"{e['type']:<24}{e['size']:>14}{e['size'] / 1048576:>10.1f}  {e['header']}")

        if args.list or not args.out:
            return

        os.makedirs(args.out, exist_ok=True)
        seen = {}
        for e in entries:
            t = e["type"]
            if t in seen:
                seen[t] += 1
                name = f"{t.lower()}_part{seen[t]}"
            else:
                seen[t] = 0
                name = t.lower()
            dst = os.path.join(args.out, name + ".img")
            fh.seek(e["payload"])
            left = e["size"]
            with open(dst, "wb", buffering=1 << 22) as out:
                while left:
                    chunk = fh.read(min(1 << 22, left))
                    if not chunk:
                        break
                    out.write(chunk)
                    left -= len(chunk)
            print(f"  -> {os.path.basename(dst):<28}{os.path.getsize(dst):>14}")
    finally:
        fh.close()
        if closer:
            closer.close()


if __name__ == "__main__":
    sys.exit(main())
