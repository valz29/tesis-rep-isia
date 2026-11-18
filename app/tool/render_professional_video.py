#!/usr/bin/env python3
"""Encode the professional walkthrough's native Flutter frames and chapter index."""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import shutil
import subprocess


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recording_dir", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    recording = args.recording_dir.resolve()
    manifest = recording / "frames.ffconcat"
    script = recording / "guion.txt"
    if not manifest.is_file() or not script.is_file():
        parser.error("Finish recording before encoding: frames.ffconcat and guion.txt are required.")
    encoder = shutil.which("ffmpeg")
    if encoder is None:
        parser.error("ffmpeg must be installed.")
    duration = sum(float(value) for value in re.findall(
        r"^duration ([\d.]+)$", manifest.read_text(), re.MULTILINE))
    sections = [(0, "Retinazo - Flujo del profesional")]
    for minutes, seconds, title in re.findall(
        r"^(\d+):(\d+)  (.+)$", script.read_text(), re.MULTILINE
    ):
        sections.append(((int(minutes) * 60 + int(seconds)) * 1000, title))
    metadata = [";FFMETADATA1", "title=Retinazo - Flujo completo del profesional",
                "comment=Pantallas de Flutter con datos ficticios. Servicios externos representados localmente. IA pendiente."]
    for i, (start, title) in enumerate(sections):
        end = sections[i + 1][0] if i + 1 < len(sections) else round(duration * 1000)
        if end <= start:
            continue
        escaped = re.sub(r"([=;#\\])", r"\\\1", title)
        metadata += ["[CHAPTER]", "TIMEBASE=1/1000", f"START={start}", f"END={end}", f"title={escaped}"]
    metadata_path = recording / "chapters.ffmetadata"
    metadata_path.write_text("\n".join(metadata) + "\n")
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        encoder, "-hide_banner", "-loglevel", "warning", "-y",
        "-f", "concat", "-safe", "0", "-i", str(manifest),
        "-f", "ffmetadata", "-i", str(metadata_path),
        "-map", "0:v:0", "-map_metadata", "1", "-map_chapters", "1",
        "-vf", "fps=30", "-c:v", "libx264", "-threads", "2",
        "-preset", "veryfast", "-crf", "21", "-pix_fmt", "yuv420p",
        "-an", "-movflags", "+faststart", str(output),
    ], check=True)
    shutil.copy2(script, output.with_suffix(".txt"))
    print(f"Video: {output}\nDuration: {duration:.1f} seconds\nChapters: {len(sections)}")


if __name__ == "__main__":
    main()
