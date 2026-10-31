"""Build the players' release of TWD Access: build/release/TWDAccess-<version>.zip.

The zip holds one folder, TWDAccess, with:
    TWDAccess.exe     the helper, self-contained (the .NET runtime is inside; nothing to install)
    prism.dll         Prism, the speech library
    mod\\              the files the helper installs into the game folder, without the development
                      modules (devconsole, devtools, discovery)
    README.txt        the players' read-me (release/README.txt)
    LICENSE.txt       the mod's licence (MIT)
    licenses\\         Prism's NOTICE and the licences of Prism and what it uses

Usage:  python tools/make_release.py
Needs:  what tools/build_mod.py needs, the .NET SDK, and tools/prism-windows-x64.zip (Prism's
        release package; its LICENSES folder and NOTICE are copied).
"""

from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "helper" / "TWDAccess" / "TWDAccess.csproj"
OUT = ROOT / "build" / "release"
STAGE = OUT / "TWDAccess"
PRISM_ZIP = ROOT / "tools" / "prism-windows-x64.zip"
DEV_MODULES = ["devconsole.lua", "devtools.lua", "discovery.lua"]


def run(args: list[str]) -> None:
    result = subprocess.run(args, cwd=ROOT)
    if result.returncode != 0:
        sys.exit(f"failed: {' '.join(args)}")


def main() -> None:
    version = re.search(r"<Version>([^<]+)</Version>", PROJECT.read_text(encoding="utf-8")).group(1)
    if OUT.exists():
        shutil.rmtree(OUT)

    run([sys.executable, str(ROOT / "tools" / "build_mod.py")])
    run(["dotnet", "publish", str(PROJECT), "-c", "Release", "-r", "win-x64", "--self-contained", "true",
         "-p:PublishSingleFile=true", "-p:IncludeNativeLibrariesForSelfExtract=true",
         "-p:DebugType=none", "-o", str(STAGE)])

    for name in DEV_MODULES:
        (STAGE / "mod" / "TWDAccess" / name).unlink(missing_ok=True)
    for pdb in STAGE.rglob("*.pdb"):
        pdb.unlink()

    shutil.copy(ROOT / "release" / "README.txt", STAGE / "README.txt")
    shutil.copy(ROOT / "LICENSE", STAGE / "LICENSE.txt")
    licenses = STAGE / "licenses"
    licenses.mkdir()
    with zipfile.ZipFile(PRISM_ZIP) as prism:
        for info in prism.infolist():
            name = info.filename
            if info.is_dir() or not (name == "NOTICE" or name.startswith("LICENSES/")):
                continue
            target = licenses / "prism" / (name[len("LICENSES/"):] if name.startswith("LICENSES/") else "NOTICE.txt")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(prism.read(info))

    archive = OUT / f"TWDAccess-{version}.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for path in sorted(STAGE.rglob("*")):
            if path.is_file():
                z.write(path, Path("TWDAccess") / path.relative_to(STAGE))
    print(f"built {archive} ({archive.stat().st_size // 1024} KB)")
    for path in sorted(STAGE.iterdir()):
        print("  " + path.name)


if __name__ == "__main__":
    main()
