#!/usr/bin/env python3
"""Small Luau-to-Lua 5.3 lowering helpers used by the CI syntax harness."""

from __future__ import annotations

import json
import re

OPEN = "\x01"
CLOSE = "\x02"


def _long_bracket(source: str, start: int) -> tuple[int, str] | None:
    match = re.match(r"\[(=*)\[", source[start:])
    if not match:
        return None
    equals = match.group(1)
    closing = "]" + equals + "]"
    end = source.find(closing, start + len(match.group(0)))
    if end < 0:
        return len(source), source[start:]
    end += len(closing)
    return end, source[start:end]


def tokenize(source: str):
    """Split code from comments and strings so regex lowering stays safe."""
    pieces: list[tuple[str, str]] = []
    code_start = 0
    index = 0

    def push_code(end: int):
        nonlocal code_start
        if end > code_start:
            pieces.append(("code", source[code_start:end]))

    while index < len(source):
        if source.startswith("--", index):
            push_code(index)
            long_comment = _long_bracket(source, index + 2)
            if long_comment:
                end, _ = long_comment
            else:
                newline = source.find("\n", index)
                end = len(source) if newline < 0 else newline
            pieces.append(("comment", source[index:end]))
            index = end
            code_start = index
            continue

        char = source[index]
        if char in "'\"`":
            push_code(index)
            quote = char
            end = index + 1
            escaped = False
            while end < len(source):
                current = source[end]
                if escaped:
                    escaped = False
                elif current == "\\":
                    escaped = True
                elif current == quote:
                    end += 1
                    break
                end += 1
            pieces.append(("string", source[index:end]))
            index = end
            code_start = index
            continue

        if char == "[":
            long_string = _long_bracket(source, index)
            if long_string:
                push_code(index)
                end, text = long_string
                pieces.append(("string", text))
                index = end
                code_start = index
                continue

        index += 1

    push_code(len(source))
    return pieces


def _find_interpolation_end(body: str, start: int) -> int:
    depth = 1
    index = start
    quote = None
    escaped = False
    while index < len(body):
        char = body[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in "'\"`":
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    return len(body)


def interp_to_concat(text: str) -> str:
    """Lower a Luau backtick string to a Lua concatenation expression."""
    body = text[1:-1]
    parts: list[str] = []
    literal: list[str] = []
    index = 0

    def flush_literal():
        if literal:
            parts.append(json.dumps("".join(literal), ensure_ascii=False))
            literal.clear()

    while index < len(body):
        char = body[index]
        if char == "\\" and index + 1 < len(body):
            literal.append(body[index + 1])
            index += 2
            continue
        if char == "{":
            flush_literal()
            end = _find_interpolation_end(body, index + 1)
            expression = body[index + 1:end].strip() or "nil"
            parts.append(f"tostring(({expression}))")
            index = end + 1
            continue
        literal.append(char)
        index += 1
    flush_literal()
    return "(" + " .. ".join(parts or ['""']) + ")"


def strip_types(code: str) -> str:
    """Remove the common Luau annotations that Lua 5.3 cannot parse."""
    previous = None
    while previous != code:
        previous = code
        code = re.sub(
            r"([,(]\s*(?:\.\.\.|[A-Za-z_][A-Za-z0-9_]*))\s*:\s*"
            r"(?![A-Za-z_][A-Za-z0-9_]*\s*\()[^,\n)]*(?=\s*[,)=])",
            r"\1",
            code,
        )
        code = re.sub(
            r"([,(]\s*(?:\.\.\.|[A-Za-z_][A-Za-z0-9_]*))\s*:\s*"
            r"(?![A-Za-z_][A-Za-z0-9_]*\s*\()"
            r"(?:\([^\n]*?\)|[A-Za-z_][A-Za-z0-9_\.\?\{\}\[\]\|<> ]*)"
            r"(?=\s*[,)=])",
            r"\1",
            code,
        )
        code = re.sub(
            r"(\blocal\s+[A-Za-z_][A-Za-z0-9_]*)\s*:\s*[^=,\n]+(?=\s*[=,\n])",
            r"\1",
            code,
        )
        code = re.sub(
            r"(\bfor\s+[A-Za-z_][A-Za-z0-9_]*)\s*:\s*[^,\n]+(?=\s*[,])",
            r"\1",
            code,
        )

    # Keep this anchored to the actual function signature.  A greedy
    # ``function ... )`` pattern also matches the closing parenthesis of a
    # method call in a one-line function body and mistakes ``object:Method``
    # for a return annotation.
    code = re.sub(
        r"((?:local\s+)?function\s*(?:[A-Za-z_][A-Za-z0-9_\.:]*\s*)?"
        r"\([^\n)]*\))\s*:\s*"
        r"(?:\([^\n)]*\)|\{[^\n}]*\}|[A-Za-z_][A-Za-z0-9_\.\?]*)",
        r"\1",
        code,
    )
    return code


def downgrade(source: str) -> str:
    """Compatibility wrapper; full lowering lives in luaucheck.prepare."""
    import luaucheck

    return luaucheck.prepare(source, stub_requires=False)
