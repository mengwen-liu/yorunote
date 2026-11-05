"""Generate Windows icon sizes from the existing Yorunote PNG, without editing it."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/app_icon.png"
OUTPUT = ROOT / "windows/runner/resources/yorunote.ico"
SIZES = (16, 24, 32, 48, 64, 128, 256)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    source_bytes = SOURCE.read_bytes()
    with Image.open(SOURCE) as image:
        image.load()
        assert image.format == "PNG" and image.size == (1024, 1024)
        rgba = image.convert("RGBA")
    rgba.save(OUTPUT, format="ICO", sizes=[(s, s) for s in SIZES])
    with Image.open(OUTPUT) as icon:
        assert icon.ico.sizes() == {(s, s) for s in SIZES}
        for size in SIZES:
            actual = icon.ico.getimage((size, size)).convert("RGBA")
            expected = rgba.resize((size, size), Image.Resampling.LANCZOS)
            assert actual.tobytes() == expected.tobytes(), size
    sheet = Image.new("RGB", (sum(SIZES) + 12 * (len(SIZES) + 1), 340), "#e8edf3")
    draw = ImageDraw.Draw(sheet)
    x = 12
    for size in SIZES:
        tile = rgba.resize((size, size), Image.Resampling.LANCZOS)
        sheet.paste(tile, (x, 36), tile)
        draw.text((x, 12), str(size) + " px", fill="#17283b")
        x += size + 12
    sheet.save(evidence / "windows-icon-preview.png")
    manifest = {
        "source": "assets/app_icon.png",
        "source_sha256": hashlib.sha256(source_bytes).hexdigest(),
        "source_size": [1024, 1024],
        "output": "windows/runner/resources/yorunote.ico",
        "output_sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "sizes": list(SIZES),
        "pixel_comparisons": "all sizes match source resized with Pillow LANCZOS",
    }
    (evidence / "icon.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
