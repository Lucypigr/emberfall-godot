from __future__ import annotations

import argparse
import hashlib
import sys
import urllib.request
from pathlib import Path

# Use a TrueType-outline font for the Web build. The previous OTF/CFF file was
# accepted by desktop/headless Godot but still produced missing-glyph boxes on
# iPhone Safari. This file is imported by Godot before export and loaded as a
# normal project FontFile resource (not with load_dynamic_font at runtime).
FONT_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanstc/NotoSansTC%5Bwght%5D.ttf"
FONT_NAME = "NotoSansTC-Riftforged.ttf"
TTF_MAGIC = b"\x00\x01\x00\x00"


def prepare_font(project_root: Path) -> Path:
    output = project_root / "fonts" / FONT_NAME
    output.parent.mkdir(parents=True, exist_ok=True)

    if output.exists():
        data = output.read_bytes()
        if len(data) > 5_000_000 and data[:4] == TTF_MAGIC:
            return output
        output.unlink()

    request = urllib.request.Request(
        FONT_URL,
        headers={"User-Agent": "Riftforged-v2-font-builder/2.0"},
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        data = response.read()

    if len(data) < 5_000_000:
        raise RuntimeError(f"Downloaded font is unexpectedly small: {len(data)} bytes")
    if data[:4] != TTF_MAGIC:
        raise RuntimeError(f"Downloaded file is not a TrueType font: magic={data[:4]!r}")

    output.write_bytes(data)
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default="godot_v2")
    args = parser.parse_args()

    project_root = Path(args.project).resolve()
    output = prepare_font(project_root)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    print(f"Prepared {output} ({output.stat().st_size} bytes, sha256={digest})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
