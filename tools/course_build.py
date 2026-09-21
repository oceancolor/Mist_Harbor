"""Build the course as a static HTML site.

Markdown under course/ is the design source; this script is the publishing step:
  course/chapters/*.md  +  course/media/**  ->  course/site/*.html

Features
- one self-contained-ish HTML per chapter (nav, TOC, meta, gallery, video slot)
- images are copied to site/assets and rewritten; --embed inlines them as base64
  so a single .html file can be mailed or dropped into an LMS
- video: drop a file at course/media/video/<chapter-key>/*.mp4 (or .webm/.mov)
  and it is embedded with the first screenshot as poster; otherwise a placeholder
  card shows the recording script slot
- course/index.html (course home), course/site/syllabus.html (task list),
  course/site/build-info.json (stats)

Usage:
  python tools/course_build.py              # build the site
  python tools/course_build.py --embed      # inline images/CSS (single-file pages)
  python tools/course_build.py --serve 8200 # build and preview over HTTP
"""
from __future__ import annotations

import argparse
import base64
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COURSE = ROOT / "course"
CHAPTERS = COURSE / "chapters"
MEDIA = COURSE / "media"
SHOTS = MEDIA / "shots"
VIDEO = MEDIA / "video"
SITE = COURSE / "site"
ASSETS = SITE / "assets"

VOLUMES = {
    "0": "卷 0 · 启程", "1": "卷 1 · 设计先行", "2": "卷 2 · Godot 工程",
    "3": "卷 3 · 资产管线", "4": "卷 4 · 玩法系统", "5": "卷 5 · 多端发行",
    "6": "卷 6 · 质量与协作", "7": "卷 7 · 商业化",
}

STYLE = """
:root{--ink:#2d514b;--muted:#789087;--paper:#f7f8ed;--accent:#497c6b;--line:#dbe3d5;--card:#ffffff}
*{box-sizing:border-box}
body{margin:0;background:var(--paper);color:var(--ink);
 font-family:'Microsoft YaHei','PingFang SC','Noto Sans CJK SC',system-ui,sans-serif;line-height:1.75}
.wrap{display:flex;max-width:1180px;margin:0 auto;gap:28px;padding:0 20px}
nav.toc{position:sticky;top:0;align-self:flex-start;width:230px;flex:0 0 230px;
 padding:24px 0;font-size:14px;max-height:100vh;overflow:auto}
nav.toc a{display:block;color:var(--muted);text-decoration:none;padding:5px 8px;border-radius:6px}
nav.toc a:hover{background:#eef3ea;color:var(--ink)}
nav.toc .home{font-weight:700;color:var(--accent);margin-bottom:10px}
main{flex:1;min-width:0;padding:24px 0 80px}
header.top{background:linear-gradient(135deg,#e8f0e6,#f7f8ed);border-bottom:1px solid var(--line)}
header.top .inner{max-width:1180px;margin:0 auto;padding:26px 20px}
header.top h1{margin:0;font-size:26px}
header.top .meta{color:var(--muted);font-size:13px;margin-top:6px}
h2{margin-top:38px;padding-bottom:6px;border-bottom:2px solid var(--line);font-size:21px}
h3{margin-top:26px;font-size:17px}
blockquote{margin:16px 0;padding:12px 16px;background:#f0f5ec;border-left:4px solid var(--accent);border-radius:0 8px 8px 0}
blockquote p{margin:6px 0}
table{border-collapse:collapse;width:100%;margin:14px 0;font-size:14px;background:var(--card)}
th,td{border:1px solid var(--line);padding:8px 10px;text-align:left;vertical-align:top}
th{background:#eef3ea}
code{background:#eef3ea;padding:2px 5px;border-radius:4px;font-size:13px}
pre{background:#26332f;color:#e8f0e6;padding:14px 16px;border-radius:10px;overflow:auto}
pre code{background:none;color:inherit;padding:0}
.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:16px;margin:18px 0}
figure{margin:0;background:var(--card);border:1px solid var(--line);border-radius:10px;overflow:hidden}
figure img{width:100%;display:block}
figcaption{font-size:12px;color:var(--muted);padding:8px 10px;border-top:1px solid var(--line)}
video{width:100%;border-radius:10px;background:#000}
.card{border:1px dashed var(--line);background:#fbfdf8;border-radius:10px;padding:16px;margin:18px 0}
.card h4{margin:0 0 8px;font-size:15px}
.pager{display:flex;justify-content:space-between;gap:12px;margin:44px 0 0;border-top:1px solid var(--line);padding-top:18px}
.pager a{color:var(--accent);text-decoration:none;font-size:14px}
.badge{display:inline-block;background:var(--accent);color:#fff;border-radius:999px;
 padding:2px 10px;font-size:12px;margin-right:6px}
.badge.todo{background:#b9bcad}
ul,ol{padding-left:22px}
footer.foot{border-top:1px solid var(--line);margin-top:40px;padding:16px 20px;color:var(--muted);font-size:13px;text-align:center}
@media (max-width:900px){.wrap{flex-direction:column}nav.toc{position:static;width:auto;max-height:none}}
"""

TEMPLATE = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} · 雾港造物记教程</title>
{style_block}</head><body>
<header class="top"><div class="inner">
  <h1>{title}</h1>
  <div class="meta">{volume} · 字符数 {chars} · 生成于 {built}</div>
</div></header>
<div class="wrap">
{sidebar}
<main>
{body}
{pager}
</main></div>
<footer class="foot">由 <code>tools/course_build.py</code> 从 Markdown 生成 · Markdown 是设计稿，本站是成品</footer>
</body></html>"""


def chapter_key(path: Path) -> str:
    return path.stem.split("-")[-1]


def chapter_volume(path: Path) -> str:
    match = re.match(r"vol(\d)-", path.stem)
    return VOLUMES.get(match.group(1), "正文") if match else "正文"


def md_to_html(text: str) -> str:
    """Use python-markdown when installed, otherwise the built-in converter.

    The course tools stay usable with a bare Python: no reader should need pip to
    rebuild the book.
    """
    try:
        import markdown  # noqa: PLC0415
    except ImportError:
        return _simple_markdown(text)
    return markdown.markdown(
        text,
        extensions=["tables", "fenced_code", "toc", "sane_lists", "attr_list", "nl2br"],
    )


def _inline(value: str) -> str:
    import html

    value = html.escape(value, quote=False)
    value = re.sub(r"`([^`]+)`", r"<code>\1</code>", value)
    value = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", value)
    value = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", r'<img src="\2" alt="\1">', value)
    value = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', value)
    return value


def _simple_markdown(text: str) -> str:
    """Dependency-free converter for the Markdown subset this course uses."""
    import html as html_module

    lines = text.splitlines()
    out: list[str] = []
    index = 0
    paragraph: list[str] = []

    def flush() -> None:
        if paragraph:
            out.append("<p>" + "<br>".join(_inline(line) for line in paragraph) + "</p>")
            paragraph.clear()

    while index < len(lines):
        line = lines[index]
        stripped = line.strip()
        if stripped.startswith("```"):
            flush()
            index += 1
            code: list[str] = []
            while index < len(lines) and not lines[index].strip().startswith("```"):
                code.append(lines[index])
                index += 1
            index += 1
            out.append("<pre><code>" + html_module.escape("\n".join(code)) + "</code></pre>")
            continue
        if not stripped:
            flush()
            index += 1
            continue
        heading = re.match(r"^(#{1,6})\s+(.*)$", stripped)
        if heading:
            flush()
            level = len(heading.group(1))
            out.append(f"<h{level}>{_inline(heading.group(2))}</h{level}>")
            index += 1
            continue
        if re.match(r"^([-*_])\1{2,}$", stripped):
            flush()
            out.append("<hr>")
            index += 1
            continue
        if stripped.startswith(">"):
            flush()
            quote: list[str] = []
            while index < len(lines) and lines[index].strip().startswith(">"):
                quote.append(lines[index].strip().lstrip(">").strip())
                index += 1
            out.append("<blockquote><p>" + "<br>".join(_inline(q) for q in quote if q) + "</p></blockquote>")
            continue
        if stripped.startswith("|"):
            flush()
            rows: list[list[str]] = []
            while index < len(lines) and lines[index].strip().startswith("|"):
                cells = [c.strip() for c in lines[index].strip().strip("|").split("|")]
                rows.append(cells)
                index += 1
            if len(rows) >= 2:
                header, *body = rows
                if not all(set(cell) <= set(":- ") for cell in body[0]):
                    body.insert(0, None)  # keep alignment row out of the body
                table = ["<table><thead><tr>" + "".join(f"<th>{_inline(c)}</th>" for c in header) + "</tr></thead><tbody>"]
                for row in body:
                    if row is None:
                        continue
                    table.append("<tr>" + "".join(f"<td>{_inline(c)}</td>" for c in row) + "</tr>")
                table.append("</tbody></table>")
                out.append("".join(table))
            continue
        if re.match(r"^[-*]\s+", stripped) or re.match(r"^\d+\.\s+", stripped):
            flush()
            ordered = bool(re.match(r"^\d+\.\s+", stripped))
            items: list[str] = []
            pattern = re.compile(r"^\d+\.\s+" if ordered else r"^[-*]\s+")
            while index < len(lines) and pattern.match(lines[index].strip()):
                items.append(pattern.sub("", lines[index].strip()))
                index += 1
            tag = "ol" if ordered else "ul"
            out.append(f"<{tag}>" + "".join(f"<li>{_inline(i)}</li>" for i in items) + f"</{tag}>")
            continue
        paragraph.append(stripped)
        index += 1
    flush()
    return "\n".join(out)


def rewrite_media(html: str) -> str:
    """course-relative media paths -> site asset paths."""
    html = html.replace("../media/diagrams/", "assets/diagrams/")
    html = html.replace("course/media/shots/", "assets/shots/")
    html = html.replace("../media/shots/", "assets/shots/")
    return html


def embed_assets(html: str) -> str:
    """Inline every referenced asset as base64 so the page is a single file."""
    def replace(match: re.Match) -> str:
        path = SITE / match.group(1)
        if not path.is_file():
            return match.group(0)
        mime = "image/svg+xml" if path.suffix == ".svg" else "image/png"
        data = base64.b64encode(path.read_bytes()).decode("ascii")
        return f'src="data:{mime};base64,{data}"'

    return re.sub(r'src="((?:assets)/[^"]+)"', replace, html)


def gallery_html(key: str) -> str:
    directory = SHOTS / key
    if not directory.is_dir():
        return ""
    items = []
    for image in sorted(directory.glob("*.png")):
        items.append(
            f'<figure><img src="assets/shots/{key}/{image.name}" alt="{image.stem}">'
            f"<figcaption>{image.name}</figcaption></figure>"
        )
    if not items:
        return ""
    return '<h2>🖼 本章图集</h2><div class="gallery">' + "".join(items) + "</div>"


def video_html(key: str) -> str:
    directory = VIDEO / key
    sources = sorted(
        p for p in (directory.glob("*") if directory.is_dir() else [])
        if p.suffix.lower() in {".mp4", ".webm", ".mov", ".m4v"}
    )
    if sources:
        poster = ""
        cover = sorted((SHOTS / key).glob("*.png")) if (SHOTS / key).is_dir() else []
        if cover:
            poster = f' poster="assets/shots/{key}/{cover[0].name}"'
        video = sources[0]
        return (f'<h2>🎬 本章视频</h2><video controls{poster} preload="metadata">'
                f'<source src="assets/video/{key}/{video.name}"></video>'
                f'<p class="meta">若浏览器不支持，可直接打开 '
                f'<code>course/media/video/{key}/{video.name}</code></p>')
    return ('<div class="card"><h4>🎬 视频位（待录制）</h4>'
            '把录好的视频放到 <code>course/media/video/' + key + '/</code>'
            '（mp4 / webm / mov），重新执行 <code>python tools/course_build.py</code> 即会自动内嵌；'
            '首帧默认用本章第一张截图作为封面。分镜脚本见上一节。</div>')


def insert_media_sections(html: str, key: str) -> str:
    gallery = gallery_html(key)
    video = video_html(key)
    pattern = re.compile(r"<h2[^>]*>[^<]*录屏分镜[^<]*</h2>")
    match = pattern.search(html)
    if not match:
        return html + gallery + video
    # video goes after the storyboard section (before the next h2, or at the end)
    rest = html[match.end():]
    nxt = re.search(r"<h2[^>]*>", rest)
    if nxt:
        html = html[:match.end()] + rest[:nxt.start()] + video + rest[nxt.start():]
    else:
        html = html + video
    head, tail = html[:match.start()], html[match.start():]
    return head + gallery + tail


def sidebar(entries: list[tuple[str, str, str]], current: str) -> str:
    links = ['<a class="home" href="index.html">课程首页</a>',
             '<a href="syllabus.html">任务清单 T01–T48</a>']
    if (COURSE / "appendix.md").is_file():
        cls = ' style="color:#2d514b;font-weight:700"' if current == "appendix" else ""
        links.append(f'<a href="appendix.html"{cls}>附录 · 速查与索引</a>')
    for key, title, _ in entries:
        cls = ' style="color:#2d514b;font-weight:700"' if key == current else ""
        links.append(f'<a href="chapter-{key}.html"{cls}>{title}</a>')
    return '<nav class="toc">' + "".join(links) + "</nav>"


def build(embed: bool) -> dict:
    from datetime import datetime

    if SITE.exists():
        shutil.rmtree(SITE)
    (ASSETS / "diagrams").mkdir(parents=True, exist_ok=True)
    (ASSETS / "shots").mkdir(parents=True, exist_ok=True)
    for svg in (MEDIA / "diagrams").glob("*.svg"):
        shutil.copy2(svg, ASSETS / "diagrams" / svg.name)
    for folder in SHOTS.iterdir():
        if folder.is_dir():
            target = ASSETS / "shots" / folder.name
            shutil.copytree(folder, target, dirs_exist_ok=True)
    if VIDEO.is_dir():
        for folder in VIDEO.iterdir():
            if folder.is_dir():
                shutil.copytree(folder, ASSETS / "video" / folder.name, dirs_exist_ok=True)

    chapters = sorted(CHAPTERS.glob("*.md"))
    entries: list[tuple[str, str, str]] = []
    for path in chapters:
        text = path.read_text(encoding="utf-8")
        title = next(line[2:].strip() for line in text.splitlines() if line.startswith("# "))
        entries.append((chapter_key(path), title, chapter_volume(path)))

    style_block = f"<style>{STYLE}</style>" if embed else '<link rel="stylesheet" href="assets/style.css">'
    if not embed:
        (ASSETS / "style.css").write_text(STYLE, encoding="utf-8")

    built = datetime.now().strftime("%Y-%m-%d %H:%M")
    stats = {"built": built, "chapters": [], "characters": 0}
    for index, (key, title, volume) in enumerate(entries):
        path = next(p for p in chapters if chapter_key(p) == key)
        text = path.read_text(encoding="utf-8")
        html = rewrite_media(md_to_html(text))
        html = insert_media_sections(html, key)
        prev_link = (f'<a href="chapter-{entries[index-1][0]}.html">← {entries[index-1][1]}</a>'
                     if index > 0 else '<span></span>')
        next_link = (f'<a href="chapter-{entries[index+1][0]}.html">{entries[index+1][1]} →</a>'
                     if index < len(entries) - 1 else '<span></span>')
        page = TEMPLATE.format(
            title=title, volume=volume, chars=len(text), built=built,
            style_block=style_block, sidebar=sidebar(entries, key),
            body=html, pager=f'<div class="pager">{prev_link}{next_link}</div>',
        )
        if embed:
            page = embed_assets(page)
        (SITE / f"chapter-{key}.html").write_text(page, encoding="utf-8")
        stats["chapters"].append({"key": key, "title": title, "volume": volume,
                                  "characters": len(text), "file": f"chapter-{key}.html"})
        stats["characters"] += len(text)

    # task list page
    if (COURSE / "syllabus.md").is_file():
        body = rewrite_media(md_to_html((COURSE / "syllabus.md").read_text(encoding="utf-8")))
        page = TEMPLATE.format(title="任务清单 T01–T48", volume="实践路线", built=built,
                               chars=len((COURSE / "syllabus.md").read_text(encoding="utf-8")),
                               style_block=style_block, sidebar=sidebar(entries, ""),
                               body=body, pager="")
        (SITE / "syllabus.html").write_text(page, encoding="utf-8")

    # appendix (terminology / FAQ / pitfalls / commands / asset index)
    if (COURSE / "appendix.md").is_file():
        raw = (COURSE / "appendix.md").read_text(encoding="utf-8")
        page = TEMPLATE.format(title="附录 · 术语 / FAQ / 坑索引 / 命令速查", volume="速查与索引",
                               built=built, chars=len(raw), style_block=style_block,
                               sidebar=sidebar(entries, "appendix"),
                               body=rewrite_media(md_to_html(raw)), pager="")
        (SITE / "appendix.html").write_text(page, encoding="utf-8")

    # course home
    cards = []
    for key, title, volume in entries:
        cards.append(
            f'<div class="card"><span class="badge">{volume}</span>'
            f'<a href="chapter-{key}.html" style="color:#497c6b;font-size:16px">{title}</a></div>')
    body = ("<h2>全部章节</h2>" + "".join(cards) +
            '<h2>怎么用</h2><p>Markdown 是设计沟通的载体，<b>本站点是最终成品</b>：'
            '每章内嵌截图与视频位，可直接用于课堂教学、直播与自学。'
            '重新生成：<code>python tools/course_build.py</code>；'
            '单文件分发：<code>python tools/course_build.py --embed</code>。</p>')
    page = TEMPLATE.format(title="雾港造物记 · 用 AI Agent 从 0 做出可发行游戏",
                           volume=f"共 {len(entries)} 章 · {stats['characters']} 字",
                           built=built, chars=stats["characters"], style_block=style_block,
                           sidebar=sidebar(entries, ""), body=body, pager="")
    (SITE / "index.html").write_text(page, encoding="utf-8")
    (SITE / "build-info.json").write_text(json.dumps(stats, ensure_ascii=False, indent=2), encoding="utf-8")
    return stats


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--embed", action="store_true", help="inline images and CSS into each page")
    parser.add_argument("--serve", type=int, help="serve the site on this port after building")
    args = parser.parse_args()

    stats = build(args.embed)
    print(f"built {len(stats['chapters'])} chapter(s), {stats['characters']} characters -> {SITE}")
    for chapter in stats["chapters"]:
        print(f"  {chapter['file']}: {chapter['title']} ({chapter['characters']})")

    if args.serve:
        print(f"serving on http://127.0.0.1:{args.serve}/index.html (Ctrl+C to stop)")
        subprocess.call([sys.executable, "-m", "http.server", str(args.serve),
                         "--bind", "127.0.0.1", "--directory", str(SITE)])


if __name__ == "__main__":
    main()
