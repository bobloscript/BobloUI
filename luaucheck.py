#!/usr/bin/env python3
"""Parse every source module after lowering Luau syntax to Lua 5.3."""

from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from downgrade import CLOSE, OPEN, interp_to_concat, strip_types, tokenize


def _scan(out, pos, stops):
    depth = 0
    index = pos
    while index < len(out):
        char = out[index]
        if char in "([{":
            depth += 1
        elif char in ")]}":
            if depth == 0:
                return index, None
            depth -= 1
        elif depth == 0:
            for keyword in stops:
                before = out[index - 1:index] or " "
                after = out[index + len(keyword):index + len(keyword) + 1] or " "
                if out.startswith(keyword, index) and not re.match(r"\w", before) and not re.match(r"\w", after):
                    return index, keyword
        index += 1
    return len(out), None


def _scan_expression_end(out, pos):
    depth = 0
    index = pos
    while index < len(out):
        char = out[index]
        if char in "([{":
            depth += 1
        elif char in ")]}":
            if depth == 0:
                return index
            depth -= 1
        elif depth == 0:
            before = out[index - 1:index] or " "
            after = out[index + 3:index + 4] or " "
            if out.startswith("end", index) and not re.match(r"\w", before) and not re.match(r"\w", after):
                return index
            if char in ",\n;":
                return index
        index += 1
    return len(out)


def lower_if_expressions(code):
    pattern = re.compile(r"((?<![=~<>])=|\(|,|\{|\breturn\b|\band\b|\bor\b|\.\.)(\s*)if\s")
    out = code
    for _ in range(5000):
        matches = list(pattern.finditer(out))
        if not matches:
            return out
        lowered = False

        # Work from right to left so nested if-expressions are lowered before
        # their containing branch.  Once those are parenthesised, a small
        # delimiter scanner is sufficient for the outer expression too.
        for match in reversed(matches):
            then_at, keyword = _scan(out, match.end(), ["then", "end"])
            if keyword != "then":
                continue

            clauses = []
            condition = out[match.end():then_at]
            value_start = then_at + len("then")

            while True:
                branch_at, keyword = _scan(out, value_start, ["else", "elseif", "end"])
                if keyword not in ("else", "elseif"):
                    break
                clauses.append((condition, out[value_start:branch_at]))

                if keyword == "else":
                    end_at = _scan_expression_end(out, branch_at + len("else"))
                    result = out[branch_at + len("else"):end_at]
                    for clause_condition, clause_value in reversed(clauses):
                        result = f"(({clause_condition}) and ({clause_value}) or ({result}))"
                    replacement = match.group(1) + match.group(2) + result
                    out = out[:match.start()] + replacement + out[end_at:]
                    lowered = True
                    break

                condition_start = branch_at + len("elseif")
                next_then, next_keyword = _scan(out, condition_start, ["then", "end"])
                if next_keyword != "then":
                    break
                condition = out[condition_start:next_then]
                value_start = next_then + len("then")

            if lowered:
                break

        if not lowered:
            return out
    return out


def strip_type_declarations(code):
    output = []
    cursor = 0
    pattern = re.compile(r"^[ \t]*(export[ \t]+)?type[ \t]+\w+[ \t]*(<[^>]*>)?[ \t]*=", re.M)
    for match in pattern.finditer(code):
        if match.start() < cursor:
            continue
        output.append(code[cursor:match.start()])
        index = match.end()
        depth = 0
        while index < len(code):
            char = code[index]
            if char in "{([":
                depth += 1
            elif char in "})]":
                depth -= 1
            elif char == "\n" and depth <= 0:
                break
            index += 1
        cursor = index
    output.append(code[cursor:])
    return "".join(output)


def prepare(source, stub_requires=True):
    masked = []
    literals = []
    for kind, text in tokenize(source):
        if kind == "code":
            masked.append(text)
        else:
            masked.append(f"{OPEN}{len(literals)}{CLOSE}")
            literals.append((kind, text))
    code = "".join(masked)

    code = strip_type_declarations(code)
    code = re.sub(r"\)\s*:\s*\([A-Za-z0-9_\.\{\}\[\]\|\?\s,]*\)(?=\s*$)", ")", code, flags=re.M)
    code = re.sub(r"\bcontinue\b", "", code)
    code = re.sub(r"::\s*[A-Za-z0-9_\.\{\}\[\]\|\?\s,<>()]+?(?=[,)\]\}\n=])", "", code)
    code = strip_types(code)
    code = lower_if_expressions(code)
    code = re.sub(r"([A-Za-z_][A-Za-z0-9_\.\[\]\x01\x02]*)\s*\+=\s*", r"\1 = \1 + ", code)
    code = re.sub(r"([A-Za-z_][A-Za-z0-9_\.\[\]\x01\x02]*)\s*-=\s*", r"\1 = \1 - ", code)
    code = re.sub(r"([A-Za-z_][A-Za-z0-9_\.\[\]\x01\x02]*)\s*\*=\s*", r"\1 = \1 * ", code)
    code = re.sub(r"([A-Za-z_][A-Za-z0-9_\.\[\]\x01\x02]*)\s*//=\s*", r"\1 = \1 // ", code)
    def lower_generalized_iteration(match):
        variables = match.group(1)
        expression = match.group(2).strip()
        if re.match(r"^(pairs|ipairs|next)\s*\(", expression):
            return match.group(0)
        return f"for {variables} in pairs({expression}) do"

    code = re.sub(
        r"\bfor\s+([^\n]*?)\s+in\s+([^\n]*?)\s+do",
        lower_generalized_iteration,
        code,
    )
    if stub_requires:
        code = re.sub(r'require\(\s*"@[A-Za-z0-9_./-]+"\s*\)', "({})", code)
    else:
        code = re.sub(r'require\(\s*"@([A-Za-z0-9_./-]+)"\s*\)', r'__require("\1")', code)

    def restore(match):
        kind, text = literals[int(match.group(1))]
        if kind == "string" and text.startswith("`"):
            return interp_to_concat(text)
        if kind == "comment":
            return "\n" * text.count("\n")
        return text

    return re.sub(OPEN + r"(\d+)" + CLOSE, restore, code)


def lua_binary():
    configured = None
    if len(sys.argv) > 1 and sys.argv[1].startswith("--lua="):
        configured = sys.argv.pop(1).split("=", 1)[1]
    for candidate in (configured, "lua5.3", "texlua", "lua"):
        if candidate and shutil.which(candidate):
            return candidate
    raise SystemExit("Lua 5.3 interpreter not found (tried lua5.3, texlua, lua)")


def main():
    root = pathlib.Path(__file__).parent
    files = sorted((root / "src").rglob("*.lua"))
    bad = []
    interpreter = lua_binary()
    with tempfile.TemporaryDirectory(prefix="bobloui-luaucheck-") as directory:
        directory_path = pathlib.Path(directory)
        for index, file in enumerate(files):
            prepared = prepare(file.read_text(encoding="utf-8"))
            target = directory_path / f"module-{index}.lua"
            target.write_text(prepared, encoding="utf-8")
            probe = directory_path / f"probe-{index}.lua"
            probe.write_text(
                f'local f,e=loadfile({str(target)!r}) if not f then print(e) os.exit(1) end',
                encoding="utf-8",
            )
            result = subprocess.run([interpreter, str(probe)], capture_output=True, text=True)
            if result.returncode != 0:
                bad.append((str(file.relative_to(root)), result.stdout.strip() or result.stderr.strip()))

    for file, error in bad:
        print(f"{file}\n    {error}")
    print(f"\nparsed {len(files) - len(bad)}/{len(files)}")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
