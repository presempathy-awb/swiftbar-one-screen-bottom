#!/usr/bin/env python3
"""Embed overlay sources into macos-install.sh so one curl is enough."""
from __future__ import annotations

import base64
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "macos-install.sh"
BEGIN = "# BEGIN_EMBEDDED_PAYLOADS"
END = "# END_EMBEDDED_PAYLOADS"
FILES = (
    ("one-screen-bottom.5s.sh", "755"),
    ("one-screen-bottom-launch.5s.sh", "755"),
    ("lib/bar-state.sh", "644"),
    ("lib/swiftbar-park.sh", "644"),
    ("bin/bottom-overlay.swift", "644"),
)


def payload_block() -> str:
    lines = [BEGIN]
    for rel, mode in FILES:
        data = (ROOT / rel).read_bytes()
        b64 = base64.b64encode(data).decode("ascii")
        lines.append(f"# FILE {rel}")
        lines.append(f"# MODE {mode}")
        lines.append(f"# SHA256 {hashlib.sha256(data).hexdigest()}")
        for i in range(0, len(b64), 76):
            lines.append(b64[i : i + 76])
        lines.append("# END_FILE")
    lines.append(END)
    return "\n".join(lines) + "\n"


def replace_payloads(text: str, block: str) -> str:
    start = text.find(BEGIN)
    end = text.find(END, start + len(BEGIN) if start >= 0 else 0)
    if start < 0 or end < 0:
        raise SystemExit("macos-install.sh missing payload markers")
    end += len(END)
    if end < len(text) and text[end] == "\n":
        end += 1
    return text[:start] + block + text[end:]


def main() -> None:
    missing = [rel for rel, _ in FILES if not (ROOT / rel).is_file()]
    if missing:
        raise SystemExit("missing: " + ", ".join(missing))
    original = INSTALLER.read_text(encoding="utf-8")
    updated = replace_payloads(original, payload_block())
    INSTALLER.write_text(updated, encoding="utf-8")
    print(f"packed {len(FILES)} files into {INSTALLER.name}")


if __name__ == "__main__":
    main()
