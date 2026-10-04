"""Build the files TWD Access installs into the game folder, laid out exactly as they are installed:

    build/mod/Archives/DebugLoader.lua   bootstrap, in the game's script format
    build/mod/TWDAccess/*.lua            the mod itself, plain Lua 5.2 (loaded by the bootstrap)

The Definitive Series only runs scripts from its resource system when they are in Telltale's
encrypted script format ("\\x1bLEo" header). Like every Definitive Series mod, the bootstrap is put
into that format with the community packaging tool ttarchext (Luigi Auriemma), exactly as the
Telltale Modding Group's Script Editor does:
    ttarchext -V 7 -e 0 -o 67 <script.lua> <output folder>
Game number 67 is "The Walking Dead: The Telltale Definitive Series". It is only ever run on our
own bootstrap; everything else stays plain text.

Usage:  python tools/build_mod.py
Needs:  tools/ttarchext/ttarchext.exe (github.com/Telltale-Modding-Group/Telltale-Script-Editor,
        resources/ttarchext.exe) and `pip install lupa` for the Lua syntax check.
"""

from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
BOOTSTRAP = ROOT / "mod" / "src" / "DebugLoader.lua"
LUA_DIR = ROOT / "mod" / "lua"
OUT = ROOT / "build" / "mod"
STAGE = ROOT / "build" / "stage"
TTARCHEXT = ROOT / "tools" / "ttarchext" / "ttarchext.exe"
GAME_NUMBER = "67"


def check_syntax(source: str, chunk_name: str) -> None:
    """The game only fails silently on a syntax error, so catch them here."""
    try:
        from lupa import lua52
    except ImportError:
        sys.exit("the syntax check needs the 'lupa' package: python -m pip install lupa")
    lua = lua52.LuaRuntime(encoding=None)
    check = lua.eval(b"function(src, name) local f, err = load(src, name, 't'); return err end")
    err = check(source.encode("utf-8"), ("@" + chunk_name).encode("utf-8"))
    if err:
        sys.exit(f"Lua syntax error: {err.decode('utf-8', 'replace')}")


def encrypt(plain: Path, out_dir: Path) -> None:
    if not TTARCHEXT.exists():
        sys.exit(f"missing {TTARCHEXT}; see the header of this script")
    result = subprocess.run(
        [str(TTARCHEXT), "-V", "7", "-e", "0", "-o", GAME_NUMBER, str(plain), str(out_dir)],
        capture_output=True, text=True)
    produced = out_dir / plain.name
    if result.returncode != 0 or not produced.exists() or produced.read_bytes()[:4] != b"\x1bLEo":
        sys.exit(f"ttarchext failed for {plain.name}:\n{result.stdout}\n{result.stderr}")


def main() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    if STAGE.exists():
        shutil.rmtree(STAGE)
    archives = OUT / "Archives"
    mod_dir = OUT / "TWDAccess"
    for d in (archives, mod_dir, STAGE):
        d.mkdir(parents=True)

    source = BOOTSTRAP.read_text(encoding="utf-8")
    check_syntax(source, BOOTSTRAP.name)
    staged = STAGE / BOOTSTRAP.name
    staged.write_bytes(source.encode("utf-8"))
    encrypt(staged, archives)
    print(f"built Archives/{BOOTSTRAP.name} (game script format)")

    for lua in sorted(LUA_DIR.glob("*.lua")):
        text = lua.read_text(encoding="utf-8")
        check_syntax(text, lua.name)
        (mod_dir / lua.name).write_bytes(text.encode("utf-8"))
        print(f"built TWDAccess/{lua.name}")


if __name__ == "__main__":
    main()
