#!/usr/bin/env python3
import argparse
import hashlib
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser(description="Generate a versioned Homebrew cask from a Tomales release.")
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
    parser.error("VERSION must be a stable numeric version")
if args.archive.name != f"Tomales-{version}.zip" or not args.archive.is_file():
    parser.error("Archive is missing or does not match VERSION")
binary = args.archive.parent / "Tomales.app/Contents/MacOS/Tomales"
architectures = subprocess.check_output(["/usr/bin/lipo", "-archs", str(binary)], text=True).split()
if set(architectures) != {"arm64", "x86_64"}:
    parser.error("Published casks require a universal arm64 + x86_64 app")
with args.archive.open("rb") as stream:
    digest = hashlib.file_digest(stream, "sha256").hexdigest() if hasattr(hashlib, "file_digest") else hashlib.sha256(stream.read()).hexdigest()
text = f'''cask "tomales" do
  version "{version}"
  sha256 "{digest}"

  url "https://github.com/{args.repository}/releases/download/v#{{version}}/Tomales-#{{version}}.zip"
  name "Tomales"
  desc "Keep display awake and monitor memory, CPU, process power, and fans"
  homepage "https://github.com/{args.repository}"

  depends_on macos: ">= :ventura"
  app "Tomales.app"

  uninstall quit: "app.tomales.menubar"
  zap trash: "~/Library/Preferences/app.tomales.menubar.plist"

  caveats <<~EOS
    Updating restarts Tomales and ends any active keep-awake session.
    Update and reopen: brew upgrade --cask {args.tap}/tomales && open -a Tomales
  EOS
end
'''
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(text)
print(f"Generated {args.output}")
