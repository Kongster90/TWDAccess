"""Runs tools/dev/offline_lookaround.lua against mod/lua/lookaround.lua with lupa (Lua 5.2).

Usage: python tools/dev/offline_lookaround.py [folder holding lupa]
(pip install lupa, or pip install --target <folder> lupa and pass the folder.)
"""
import sys
from pathlib import Path

if len(sys.argv) > 1:
    sys.path.insert(0, sys.argv[1])
from lupa import lua52

root = Path(__file__).resolve().parents[2]
harness = (root / "tools" / "dev" / "offline_lookaround.lua").read_text(encoding="utf-8")
source = (root / "mod" / "lua" / "lookaround.lua").read_text(encoding="utf-8")
lua = lua52.LuaRuntime(encoding="utf-8")
run = lua.execute("return function(h, s) local f = assert(load(h, '@offline_lookaround.lua')); return f(s) end")
run(harness, source)
