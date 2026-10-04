#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, sys

EXPECTED_DEFAULT = "DEB116644000DB00BF2A54101AE6F923C89C073FBE3F1CA6FDF231CD2A21FCB3"
BASE_DEFAULT = 0x00400000

def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().upper()

def parse_int(v: str) -> int:
    return int(v, 0)

def main() -> int:
    ap = argparse.ArgumentParser(description="L850 bounded x86 Capstone proof")
    ap.add_argument("--image", required=True, type=pathlib.Path)
    ap.add_argument("--va", required=True, type=parse_int)
    ap.add_argument("--before", type=parse_int, default=0x20)
    ap.add_argument("--after", type=parse_int, default=0x80)
    ap.add_argument("--base", type=parse_int, default=BASE_DEFAULT)
    ap.add_argument("--expected-sha256", default=EXPECTED_DEFAULT)
    ap.add_argument("--output", type=pathlib.Path)
    ns = ap.parse_args()

    try:
        import capstone
    except Exception as e:
        print(f"STATUS=BLOCKED_CAPSTONE_UNAVAILABLE\nERROR={e}")
        return 2

    digest = sha256(ns.image)
    if digest != ns.expected_sha256.upper():
        print("STATUS=FAIL_HASH_MISMATCH")
        print(f"EXPECTED={ns.expected_sha256.upper()}")
        print(f"ACTUAL={digest}")
        return 3

    raw = ns.image.read_bytes()
    start_va = max(ns.base, ns.va - ns.before)
    end_va = ns.va + ns.after
    start_off = start_va - ns.base
    end_off = min(len(raw), end_va - ns.base)
    if start_off < 0 or start_off >= len(raw) or end_off <= start_off:
        print("STATUS=FAIL_RANGE")
        return 4

    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    md.detail = True
    rows = []
    for ins in md.disasm(raw[start_off:end_off], start_va):
        rows.append({
            "address": f"0x{ins.address:08X}",
            "size": ins.size,
            "bytes": ins.bytes.hex(" "),
            "mnemonic": ins.mnemonic,
            "op_str": ins.op_str,
            "is_anchor": ins.address == ns.va,
        })

    result = {
        "status": "PASS",
        "image": str(ns.image),
        "sha256": digest,
        "base": f"0x{ns.base:08X}",
        "anchor_va": f"0x{ns.va:08X}",
        "window_start_va": f"0x{start_va:08X}",
        "window_end_va": f"0x{(ns.base + end_off):08X}",
        "instruction_count": len(rows),
        "instructions": rows,
    }
    out = json.dumps(result, ensure_ascii=False, indent=2)
    if ns.output:
        ns.output.parent.mkdir(parents=True, exist_ok=True)
        ns.output.write_text(out + "\n", encoding="utf-8")
    else:
        print(out)
    return 0

if __name__ == "__main__":
    sys.exit(main())
