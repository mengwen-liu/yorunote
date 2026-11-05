"""Package a checked Windows x64 build as ZIP. Never run the legacy installer.

Build first with windows/make_icon.py and flutter build windows --release --no-pub.
The old no-argument installer invocation deliberately fails at argument parsing.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def machine(path: Path) -> int:
    data = path.read_bytes()
    if data[:2] != b"MZ":
        raise ValueError("Missing DOS header: " + str(path))
    offset = struct.unpack_from("<I", data, 0x3C)[0]
    if data[offset:offset + 4] != b"PE\0\0":
        raise ValueError("Missing PE header: " + str(path))
    return struct.unpack_from("<H", data, offset + 4)[0]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.source_sha):
        parser.error("--source-sha must be a full commit SHA")
    bundle = args.bundle.resolve()
    expected = (ROOT / "build/windows/x64/runner/Release").resolve()
    if bundle != expected:
        parser.error("--bundle must be this checkout's x64 Release directory")
    output = args.output.resolve()
    evidence = args.evidence.resolve()
    output.mkdir(parents=True, exist_ok=True)
    evidence.mkdir(parents=True, exist_ok=True)
    required = [
        "yorunote.exe", "flutter_windows.dll", "rhttp.dll", "sqlite3.dll",
        "flutter_qjs_plugin.dll", "WebView2Loader.dll", "data/app.so",
        "data/icudtl.dat", "data/flutter_assets/assets/app_icon.png",
        "data/flutter_assets/assets/init.js",
    ]
    for name in required:
        path = bundle / name
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError("Required Windows runtime file missing: " + name)
    pe_files = sorted([*bundle.glob("*.exe"), *bundle.glob("*.dll")])
    native = []
    for path in pe_files:
        value = machine(path)
        if value != 0x8664:
            raise ValueError("Non-x64 PE file: " + path.name + ": " + hex(value))
        native.append({"name": path.name, "machine": "AMD64", "sha256": sha256(path)})
    if sha256(bundle / "data/flutter_assets/assets/app_icon.png") != sha256(ROOT / "assets/app_icon.png"):
        raise ValueError("Packaged About image differs from source")
    selected = sorted(
        p for p in bundle.rglob("*")
        if p.is_file() and p.suffix.lower() not in {".pdb", ".lib", ".exp"}
    )
    for path in selected:
        if path.is_symlink() or not path.resolve().is_relative_to(bundle):
            raise ValueError("Unsafe bundle path: " + str(path))
    extras = {
        "README.md": (ROOT / "windows/README.md").read_bytes(),
        "README.en.md": (ROOT / "windows/README.en.md").read_bytes(),
        "LICENSE": (ROOT / "LICENSE").read_bytes(),
    }
    info = {
        "application": "Yorunote",
        "platform": "windows-x64",
        "configuration": "Release",
        "source_commit": args.source_sha,
        "upstream_app_base": "29b590b457378c16b19821f139b9bcad7d38f689",
        "source_url": "https://github.com/mengwen-liu/yorunote/commit/" + args.source_sha,
        "flutter": "3.41.4",
        "dart": "3.11.1",
        "authenticode": "not signed",
        "installer": "not included",
        "native_libraries": native,
    }
    extras["BUILD_INFO.json"] = (json.dumps(info, ensure_ascii=False, indent=2) + "\n").encode()
    checks = [(p.relative_to(bundle).as_posix(), sha256(p)) for p in selected]
    checks += [(name, hashlib.sha256(data).hexdigest()) for name, data in extras.items()]
    extras["SHA256SUMS.txt"] = "".join(
        digest + "  " + name + "\n" for name, digest in sorted(checks)
    ).encode("utf-8")
    filename = "Yorunote_windows_x64_" + args.source_sha[:8] + "_preview.zip"
    archive = output / filename
    with zipfile.ZipFile(archive, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for path in selected:
            z.write(path, "Yorunote/" + path.relative_to(bundle).as_posix())
        for name, data in extras.items():
            z.writestr("Yorunote/" + name, data)
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        expected_names = {"Yorunote/" + name for name, _ in checks}
        assert set(z.namelist()) == expected_names | {"Yorunote/SHA256SUMS.txt"}
        for name, digest in checks:
            assert hashlib.sha256(z.read("Yorunote/" + name)).hexdigest() == digest
        packed_exe = z.read("Yorunote/yorunote.exe")
        assert hashlib.sha256(packed_exe).hexdigest() == sha256(bundle / "yorunote.exe")
    digest = sha256(archive)
    archive.with_suffix(".zip.sha256").write_bytes((digest + "  " + filename + "\n").encode("ascii"))
    info.update({"zip": filename, "zip_bytes": archive.stat().st_size, "zip_sha256": digest})
    (evidence / "package.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(info, indent=2))


if __name__ == "__main__":
    main()
