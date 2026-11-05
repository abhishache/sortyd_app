#!/usr/bin/env python3
"""Build and install Sortyd for macOS into /Applications/Sortyd.app"""
import datetime
import os
import pathlib
import subprocess
import sys

def main():
    root = pathlib.Path(__file__).resolve().parents[1]
    ios_dir = root / "ios"
    xcodeproj = ios_dir / "Sortyd.xcodeproj"
    target_app = pathlib.Path("/Applications/Sortyd.app")

    print("==> Building Sortyd for macOS...")
    cmd = [
        "xcodebuild",
        "-project", str(xcodeproj),
        "-scheme", "Sortyd",
        "-destination", "platform=macOS",
        "-configuration", "Debug",
        "CODE_SIGN_IDENTITY=",
        "CODE_SIGNING_REQUIRED=NO",
        "CODE_SIGNING_ALLOWED=NO",
        "build"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print("xcodebuild failed:")
        print(res.stderr[-2000:] if len(res.stderr) > 2000 else res.stderr)
        print(res.stdout[-2000:] if len(res.stdout) > 2000 else res.stdout)
        sys.exit(1)

    # Find the built app
    derived_data = pathlib.Path.home() / "Library/Developer/Xcode/DerivedData"
    candidates = list(derived_data.glob("Sortyd-*/Build/Products/Debug/Sortyd.app"))
    if not candidates:
        print("Error: Could not locate built Sortyd.app in DerivedData")
        sys.exit(1)

    built_app = max(candidates, key=lambda p: p.stat().st_mtime)
    print(f"==> Located built app: {built_app}")

    # Terminate running instances
    subprocess.run(["pkill", "-f", "/Applications/Sortyd.app"], check=False)

    # Archive previous installed version if exists
    if target_app.exists():
        backup_dir = root / "release/app-backups"
        backup_dir.mkdir(parents=True, exist_ok=True)
        backup_zip = backup_dir / f"Sortyd-mac-{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}.zip"
        subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(target_app), str(backup_zip)], check=False)

    # Install to /Applications
    subprocess.run(["rsync", "-a", "--delete", f"{built_app}/", f"{target_app}/"], check=True)
    print(f"==> Installed Sortyd to {target_app}")

    # Launch app
    subprocess.run(["open", str(target_app)], check=True)
    print("==> Launched Sortyd.app successfully!")

if __name__ == "__main__":
    main()
