"""Minimal Lua 5.2 bytecode disassembler (development aid).

The mod's dev console can save a loaded game function with string.dump (see devconsole notes);
this prints its instructions with constants, globals and upvalue names resolved, which is enough
to follow which functions it calls and with what.

Usage: python tools/dev/luadis.py file.luac [more.luac ...]
"""

import struct
import sys

OPS = ("MOVE LOADK LOADKX LOADBOOL LOADNIL GETUPVAL GETTABUP GETTABLE SETTABUP SETUPVAL SETTABLE "
       "NEWTABLE SELF ADD SUB MUL DIV MOD POW UNM NOT LEN CONCAT JMP EQ LT LE TEST TESTSET CALL "
       "TAILCALL RETURN FORLOOP FORPREP TFORCALL TFORLOOP SETLIST CLOSURE VARARG EXTRAARG").split()


class Reader:
    def __init__(self, data):
        self.d, self.p = data, 0
        # Header bytes 7-10: sizes of int, size_t, Instruction and lua_Number. Telltale's build uses
        # 4-byte size_t and 4-byte float numbers, stock 64-bit Lua uses 8 and 8.
        self.size_t = data[8]
        self.number = data[10]

    def take(self, n):
        b = self.d[self.p:self.p + n]
        self.p += n
        return b

    def byte(self):
        return self.take(1)[0]

    def int(self):
        return struct.unpack("<i", self.take(4))[0]

    def size(self):
        return struct.unpack("<Q" if self.size_t == 8 else "<I", self.take(self.size_t))[0]

    def num(self):
        return struct.unpack("<d" if self.number == 8 else "<f", self.take(self.number))[0]

    def string(self):
        n = self.size()
        return None if n == 0 else self.take(n)[:-1].decode("utf-8", "replace")


def read_function(r):
    f = {}
    f["line"], f["lastline"] = r.int(), r.int()
    f["params"], f["vararg"], f["stack"] = r.byte(), r.byte(), r.byte()
    f["code"] = [struct.unpack("<I", r.take(4))[0] for _ in range(r.int())]
    consts = []
    for _ in range(r.int()):
        t = r.byte()
        if t == 0:
            consts.append(None)
        elif t == 1:
            consts.append(bool(r.byte()))
        elif t == 3:
            consts.append(r.num())
        elif t == 4:
            consts.append(r.string())
        else:
            raise ValueError(f"constant type {t}")
    f["consts"] = consts
    f["protos"] = [read_function(r) for _ in range(r.int())]
    f["upvals"] = [(r.byte(), r.byte()) for _ in range(r.int())]
    f["source"] = r.string()
    f["lineinfo"] = [r.int() for _ in range(r.int())]
    f["locals"] = [(r.string(), r.int(), r.int()) for _ in range(r.int())]
    f["upnames"] = [r.string() for _ in range(r.int())]
    return f


def rk(f, x):
    if x & 0x100:
        return repr(f["consts"][x & 0xFF])
    return f"r{x}"


def local_name(f, reg, pc):
    active = [name for name, start, end in f["locals"] if start <= pc < end]
    return active[reg] if reg < len(active) else None


def show(f, indent=""):
    params = [n for n, s, e in f["locals"][:f["params"]]]
    print(f"{indent}function({', '.join(params)}{', ...' if f['vararg'] else ''})  lines {f['line']}-{f['lastline']}")
    for pc, ins in enumerate(f["code"]):
        op = OPS[ins & 0x3F]
        a, c, b = (ins >> 6) & 0xFF, (ins >> 14) & 0x1FF, (ins >> 23) & 0x1FF
        bx = (ins >> 14) & 0x3FFFF
        sbx = bx - 131071
        line = f["lineinfo"][pc] if pc < len(f["lineinfo"]) else "?"
        if op == "GETTABUP":
            up = f["upnames"][b] if b < len(f["upnames"]) else f"u{b}"
            text = f"r{a} = {up}[{rk(f, c)}]"
        elif op == "SETTABUP":
            up = f["upnames"][a] if a < len(f["upnames"]) else f"u{a}"
            text = f"{up}[{rk(f, b)}] = {rk(f, c)}"
        elif op == "GETUPVAL":
            text = f"r{a} = upvalue {f['upnames'][b] if b < len(f['upnames']) else b}"
        elif op == "SETUPVAL":
            text = f"upvalue {f['upnames'][b] if b < len(f['upnames']) else b} = r{a}"
        elif op in ("LOADK",):
            text = f"r{a} = {f['consts'][bx]!r}"
        elif op == "GETTABLE":
            text = f"r{a} = r{b}[{rk(f, c)}]"
        elif op == "SETTABLE":
            text = f"r{a}[{rk(f, b)}] = {rk(f, c)}"
        elif op == "SELF":
            text = f"r{a+1} = r{b}; r{a} = r{b}[{rk(f, c)}]"
        elif op in ("EQ", "LT", "LE"):
            text = f"if ({rk(f, b)} {op} {rk(f, c)}) ~= {a} then skip"
        elif op == "CALL":
            text = f"r{a}(" + ("args r%d..r%d" % (a + 1, a + b - 1) if b else "args to top") + f") -> {c - 1 if c else 'multi'}"
        elif op == "JMP":
            text = f"jump to {pc + 1 + sbx}"
        elif op == "CLOSURE":
            text = f"r{a} = closure #{bx}"
        elif op in ("FORPREP", "FORLOOP", "TFORLOOP"):
            text = f"r{a} jump {pc + 1 + sbx}"
        else:
            text = f"A={a} B={b} C={c}"
        name = local_name(f, a, pc + 1)
        print(f"{indent}  {pc:4d} [{line}] {op:9s} {text}" + (f"   ; {name}" if name and op not in ('CALL', 'JMP') else ""))
    for i, p in enumerate(f["protos"]):
        print(f"{indent}  -- closure #{i}")
        show(p, indent + "    ")


def summarize(f, name, indent=""):
    """One block per function: parameters, fields written on self, globals used, string constants."""
    params = [n for n, s, e in f["locals"][:f["params"]]]
    fields, globals_, strings = [], [], []
    for ins in f["code"]:
        op = OPS[ins & 0x3F]
        a, c, b = (ins >> 6) & 0xFF, (ins >> 14) & 0x1FF, (ins >> 23) & 0x1FF
        if op == "GETTABUP" and (c & 0x100):
            g = f["consts"][c & 0xFF]
            if isinstance(g, str) and g not in globals_:
                globals_.append(g)
        if op in ("SETTABLE", "GETTABLE", "SELF"):
            key = b if op == "SETTABLE" else c
            if key & 0x100:
                k = f["consts"][key & 0xFF]
                tag = ("=" if op == "SETTABLE" else "") + str(k)
                if isinstance(k, str) and tag not in fields:
                    fields.append(tag)
    for k in f["consts"]:
        if isinstance(k, str) and k not in globals_ and k not in [x.lstrip("=") for x in fields] and k not in strings:
            strings.append(k)
    print(f"{indent}{name}({', '.join(params)})")
    if fields:
        print(f"{indent}  fields: {' '.join(fields)}")
    if globals_:
        print(f"{indent}  calls/globals: {' '.join(globals_)}")
    if strings:
        print(f"{indent}  strings: {' | '.join(strings)}")
    for i, p in enumerate(f["protos"]):
        summarize(p, f"closure#{i}", indent + "    ")


def main():
    if sys.argv[1:2] == ["--summary"]:
        for path in sys.argv[2:]:
            data = open(path, "rb").read()
            r = Reader(data)
            r.take(18)
            summarize(read_function(r), path.rsplit("/", 1)[-1].rsplit("\\", 1)[-1].removesuffix(".luac"))
        return
    for path in sys.argv[1:]:
        data = open(path, "rb").read()
        if data[:4] != b"\x1bLua" or data[4] != 0x52:
            print(f"{path}: not Lua 5.2 bytecode")
            continue
        r = Reader(data)
        r.take(18)  # header
        f = read_function(r)
        print(f"===== {path}  ({f['source']})")
        show(f)


if __name__ == "__main__":
    main()
