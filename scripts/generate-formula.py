#!/usr/bin/env python3
import argparse
import hashlib
from pathlib import Path
import re

parser = argparse.ArgumentParser(description="Generate a Homebrew formula for a Tomales source release.")
parser.add_argument("--repository", required=True)
parser.add_argument("--tap", required=True)
parser.add_argument("--archive", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
for name, value in [("repository", args.repository), ("tap", args.tap)]:
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", value):
        parser.error(f"{name} must be owner/name")
if args.repository.split("/")[0].lower() != args.tap.split("/")[0].lower():
    parser.error("Release repository and tap must have the same personal owner")
root = Path(__file__).resolve().parent.parent
version = (root / "VERSION").read_text().strip()
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    parser.error("VERSION must be a numeric version")
if args.archive.name != f"Tomales-{version}-source.tar.gz" or not args.archive.is_file():
    parser.error("Source archive is missing or does not match VERSION")
digest = hashlib.sha256()
with args.archive.open("rb") as stream:
    for block in iter(lambda: stream.read(1024 * 1024), b""):
        digest.update(block)
text = (root / "homebrew/tomales.rb.in").read_text()
for key, value in {
    "__REPOSITORY__": args.repository,
    "__TAP__": args.tap,
    "__VERSION__": version,
    "__SHA256__": digest.hexdigest(),
}.items():
    text = text.replace(key, value)
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(text)
print(f"Generated {args.output}")
