#!/usr/bin/env python3
"""Remove // and /* */ from Dart sources; skip lib/l10n/generated."""
import re
from pathlib import Path


def strip_dart_comments(src: str) -> str:
    out: list[str] = []
    i, n = 0, len(src)

    def peek(k: int = 1) -> str:
        return src[i : i + k] if i + k <= n else ""

    while i < n:
        if peek(2) == "/*":
            i += 2
            depth = 1
            while i < n - 1 and depth:
                if peek(2) == "/*":
                    depth += 1
                    i += 2
                elif peek(2) == "*/":
                    depth -= 1
                    i += 2
                else:
                    i += 1
            continue

        if peek(2) == "//":
            while i < n and src[i] != "\n":
                i += 1
            continue

        if peek(3) == '"""':
            out.append('"""')
            i += 3
            while i < n:
                if peek(3) == '"""':
                    out.append('"""')
                    i += 3
                    break
                out.append(src[i])
                i += 1
            continue

        if peek(3) == "'''":
            out.append("'''")
            i += 3
            while i < n:
                if peek(3) == "'''":
                    out.append("'''")
                    i += 3
                    break
                out.append(src[i])
                i += 1
            continue

        if peek() == '"':
            out.append('"')
            i += 1
            while i < n:
                ch = src[i]
                out.append(ch)
                i += 1
                if ch == "\\" and i < n:
                    out.append(src[i])
                    i += 1
                    continue
                if ch == '"':
                    break
            continue

        if peek() == "'":
            out.append("'")
            i += 1
            while i < n:
                ch = src[i]
                out.append(ch)
                i += 1
                if ch == "\\" and i < n:
                    out.append(src[i])
                    i += 1
                    continue
                if ch == "'":
                    break
            continue

        out.append(src[i])
        i += 1

    text = "".join(out)
    text = re.sub(r"\n\s*\n\s*\n+", "\n\n", text)
    return text.rstrip() + "\n"


def main() -> None:
    root = Path(__file__).resolve().parent.parent / "lib"
    for path in sorted(root.rglob("*.dart")):
        if "l10n" in path.parts and "generated" in path.parts:
            continue
        old = path.read_text(encoding="utf-8")
        new = strip_dart_comments(old)
        if new != old:
            path.write_text(new, encoding="utf-8")
            print("stripped:", path)


if __name__ == "__main__":
    main()
