#!/usr/bin/env python3
"""Generates docs/samples/demo.txt: one section per NoMess feature, with prose
hard-wrapped at a fixed width the way a narrow terminal would."""
import re
import unicodedata
from pathlib import Path

WIDTH = 64


def width(s):
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)


def wrap(text, first="  ", rest="  "):
    # CJK characters may break anywhere; Latin words stay whole.
    tokens = re.findall(r"[A-Za-z0-9'’.,:;!?()\-/]+| |.", text)
    lines, cur = [], first
    for t in tokens:
        if width(cur + t) > WIDTH and cur.strip():
            lines.append(cur.rstrip())
            cur = rest + t.lstrip()
        else:
            cur += t
    lines.append(cur.rstrip())
    return lines


out = []


def section(title, body):
    out.extend([f"### {title}", ""] + body + ["", ""])


section("1. Claude Code 回覆：英文硬換行", wrap(
    "NoMess runs quietly in the menu bar and watches what you copy from the terminal. "
    "When a long answer from a tool like Claude Code is broken into short lines by the window width, "
    "it joins those lines back into real paragraphs before you paste.",
    first="⏺ ") + [""] + wrap(
    "Nothing is uploaded anywhere. Every rule runs locally, and copies from browsers, editors or "
    "password managers are never even read."))

section("2. 中文與中英混排", wrap(
    "終端機會依照視窗寬度把長句子切斷，所以複製出來的文字常常變成一行一行的碎片。NoMess 會判斷"
    "哪些換行只是因為寬度不夠才出現的，把它們接回完整的段落；中文字之間不會多出空白，而中文和 "
    "English words 之間原本的空白也會保留下來。"))

section("3. 列表：每一項接回，但項目之間保持分開",
    wrap("Rejoins wrapped lines inside each bullet so every item reads as one complete sentence again",
         first="  - ", rest="    ")
    + wrap("Keeps separate bullets separate, even when an item is long enough to wrap twice in a narrow window",
           first="  - ", rest="    ")
    + ["  - Short items stay exactly as they were"])

section("4. 對照組：這些內容不該被改動", [
    "  2026-10-06 09:12:01 INFO  pasteboard changed, frontmost app is Orca",
    "  2026-10-06 09:12:01 INFO  joined 4 wrapped lines, wrote result back",
    "  2026-10-06 09:12:07 INFO  pasteboard changed, frontmost app is Safari",
    "",
    "  Sources/NoMessCore/HardWrapCleaner.swift",
    "  Sources/NoMessCore/DiagramDetector.swift",
    "  Sources/NoMess/PasteboardWatcher.swift",
    "",
    "  func poll() {",
    "      guard changeCount != lastChangeCount else { return }",
    "      lastChangeCount = changeCount",
    "  }",
])

section("5. 流程圖（可測：從方框開始選、故意少選第一格）", [
    "  ┌──────────┐     ┌──────────┐     ┌──────────────┐",
    "  │ Terminal │ ──▶ │ NoMess   │ ──▶ │ 備忘錄、Mail │",
    "  └──────────┘     └──────────┘     └──────────────┘",
    "                        │",
    "                        ▼",
    "                 ┌──────────────┐",
    "                 │ 程式編輯器   │",
    "                 └──────────────┘",
])

def box_table(rows):
    cols = [max(width(r[i]) for r in rows) + 2 for i in range(len(rows[0]))]

    def rule(l, m, r):
        return "  " + l + m.join("─" * c for c in cols) + r

    def row(cells):
        return "  │" + "│".join(" " + c + " " * (cols[i] - width(c) - 1) for i, c in enumerate(cells)) + "│"

    return ([rule("┌", "┬", "┐"), row(rows[0]), rule("├", "┼", "┤")]
            + [row(r) for r in rows[1:]] + [rule("└", "┴", "┘")])


section("6. 表格（Claude Code 會把 Markdown 表格畫成這樣）", box_table([
    ["貼到哪裡", "拿到什麼"],
    ["備忘錄、Notion、Mail", "HTML，表格用等寬字型"],
    ["終端機、程式編輯器", "純文字，跟原本一樣"],
]))

section("7. 空白對齊的欄位（像 kubectl、docker ps 的輸出）", [
    "  NAME            STATUS      RESTARTS   AGE",
    "  nomess-api      Running     0          3d",
    "  nomess-worker   Running     2          12d",
    "  nomess-cron     Completed   0          5h",
])

section("8. 樹狀圖與點字圖表", [
    "  nomess/",
    "  ├── Sources/",
    "  │   ├── NoMess/",
    "  │   └── NoMessCore/",
    "  └── Tests/",
    "",
    "  CPU ⣀⣀⣠⣤⣴⣶⣾⣿⣿⣷⣶⣦⣤⣄⣀⣀⣠⣤⣶⣿",
    "  MEM ⣿⣿⣿⣿⣷⣷⣶⣶⣶⣦⣦⣤⣤⣤⣄⣄⣀⣀⣀⣀",
])

Path(__file__).resolve().parent.parent.joinpath("docs/samples/demo.txt").write_text("\n".join(out).rstrip() + "\n")
