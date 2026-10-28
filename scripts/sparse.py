#!/usr/bin/env python3
"""Android sparse image expander / merger (replacement for simg2img).

The Huawei CN super image is split into two container entries because the
UPDATE.APP size field is a u32 (max 4 GiB). Each part carries its own sparse
header; the second part starts with a DONT_CARE chunk that covers everything the
first part already wrote. So the correct merge is an *overlay*, not a concatenation:

    part0:  [FILL][RAW ....][DONT .................]   <- data up to block N
    part1:  [DONT .......][RAW ....................]   <- data from block N on

Usage:
    python sparse.py part0.img part1.img -o super.img
"""
import argparse
import os
import struct
import sys

SPARSE_MAGIC = 0xED26FF3A
CHUNK_RAW, CHUNK_FILL, CHUNK_DONT, CHUNK_CRC = 0xCAC1, 0xCAC2, 0xCAC3, 0xCAC4


def expand_overlay(parts, out_path):
    total_blocks = None
    block_size = None
    file_size = None

    offsets = []  # (path, offset) of chunks already expanded, for the final size
    with open(out_path, "wb") as out:
        for path in parts:
            with open(path, "rb") as fh:
                hdr = fh.read(28)
                if len(hdr) < 28:
                    raise SystemExit(f"{path}: too short")
                magic, _maj, _min, fhs, _chs, blk, tblks, tchunks, _csum = struct.unpack("<IHHHHIIII", hdr)
                if magic != SPARSE_MAGIC:
                    raise SystemExit(f"{path}: not a sparse image (magic {magic:#x})")
                if total_blocks is None:
                    total_blocks, block_size = tblks, blk
                    file_size = total_blocks * block_size
                elif tblks != total_blocks:
                    raise SystemExit(f"{path}: geometry mismatch ({tblks} vs {total_blocks})")

                fh.seek(fhs)
                block = 0
                for i in range(tchunks):
                    ch = fh.read(12)
                    if len(ch) < 12:
                        break
                    ctype, _r, csz, tsz = struct.unpack("<HHII", ch)
                    if ctype == CHUNK_RAW:
                        data = fh.read(csz * block_size)
                        out.seek(block * block_size)
                        out.write(data)
                    elif ctype == CHUNK_FILL:
                        fill = fh.read(4)
                        out.seek(block * block_size)
                        out.write(fill * (csz * block_size // 4))
                    elif ctype == CHUNK_DONT:
                        pass  # keep whatever is already there
                    elif ctype == CHUNK_CRC:
                        fh.read(tsz - 12)
                    else:
                        raise SystemExit(f"{path}: unknown chunk {ctype:#x} at chunk {i}")
                    block += csz
                print(f"  {os.path.basename(path):<24} chunks={tchunks:<4} blocks={block}")
        out.truncate(file_size)

    print(f"output {out_path}: {os.path.getsize(out_path)} bytes "
          f"({os.path.getsize(out_path) / 1048576:.1f} MB)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("parts", nargs="+", help="sparse parts, in order")
    ap.add_argument("-o", "--out", required=True)
    args = ap.parse_args()
    expand_overlay(args.parts, args.out)


if __name__ == "__main__":
    sys.exit(main())
