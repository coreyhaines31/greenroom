#!/usr/bin/env python3
"""Renders a share image per page and points each page's og:image and twitter:image at it.

    python3 site/_build/og_pages.py

Each page's <h1> becomes the headline (its <em> or green part on the second line), and the
kicker above it the small label, on brushed aluminium with the app icon (the Brushed family look). The
home page keeps images/og.png. Needs Google Chrome for rendering.
"""
import glob
import html
import os
import re
import subprocess
import tempfile

SITE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
BASE = "https://greenroomformac.com"

TEMPLATE = """<!doctype html><html><head><meta charset="utf-8">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow:wght@400;500;600&family=Barlow+Semi+Condensed:wght@300;600;700&display=block">
<style>
* {{ box-sizing: border-box; }}
html, body {{ margin: 0; width: 1200px; height: 630px; overflow: hidden; }}
body {{
  font-family: "Barlow", "Helvetica Neue", sans-serif; color: #161616;
  background: repeating-linear-gradient(0deg, rgba(255,255,255,.22) 0 1px, rgba(0,0,0,.035) 1px 2px, transparent 2px 3px), repeating-linear-gradient(0deg, rgba(0,0,0,.035) 0 1px, transparent 1px 7px), linear-gradient(100deg, rgba(255,255,255,0) 18%, rgba(255,255,255,.5) 40%, rgba(255,255,255,0) 64%), linear-gradient(180deg, #e7e8e9, #c3c5c7);
  padding: 84px 96px 80px; display: flex; flex-direction: column; justify-content: space-between;
}}
.brand {{ display: flex; align-items: center; gap: 16px; font: 700 34px/1 "Barlow Semi Condensed", sans-serif; }}
.brand img {{ width: 72px; height: 72px; }}
.kicker {{ display: inline-flex; align-items: center; gap: 12px; font: 600 18px/1 "Barlow Semi Condensed", sans-serif; letter-spacing: 0.26em; text-transform: uppercase; background: #1b1b1b; color: #d8d9da; padding: 10px 16px 10px 14px; border-radius: 3px; }}
.kicker i {{ width: 10px; height: 10px; border-radius: 50%; background: #8448c9; box-shadow: 0 0 8px #8448c9; }}
h1 {{ font: 600 {size}px/0.98 "Barlow Semi Condensed", sans-serif; margin: 22px 0 0; max-width: 1000px; }}
h1 em {{ display: block; font-style: normal; font-weight: 300; }}
.url {{ font-size: 24px; color: #3d3f41; }}
</style></head><body>
<div class="brand"><img src="file://{icon}" alt=""> Green Room</div>
<div><div class="kicker"><i></i>{kicker}</div><h1>{headline}</h1></div>
<div class="url">greenroomformac.com/{slug}</div>
</body></html>"""


def text(fragment):
    return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()


def headline(page):
    match = re.search(r"<h1[^>]*>(.*?)</h1>", page, re.S)
    if not match:
        return None
    inner = match.group(1)
    em = re.search(r"<em>(.*?)</em>", inner, re.S)
    main = text(re.sub(r"<em>.*?</em>", "", inner, flags=re.S))
    return html.escape(main) + (f" <em>{html.escape(text(em.group(1)))}</em>" if em else "")


def kicker(page):
    match = re.search(r'class="kicker"[^>]*>(.*?)</p>', page, re.S)
    if not match:
        return "Free for Mac"
    return html.escape(text(match.group(1)).split("·")[0].strip())


def main():
    out_dir = os.path.join(SITE, "images", "og")
    os.makedirs(out_dir, exist_ok=True)
    icon = os.path.abspath(os.path.join(SITE, "images", "icon.png"))
    pages = [p for p in glob.glob(os.path.join(SITE, "**", "*.html"), recursive=True)
             if "_build" not in p and os.path.basename(p) != "index.html" or p.endswith("fix/index.html")]
    for path in sorted(pages):
        slug = os.path.relpath(path, SITE)[:-5].replace("/index", "")
        with open(path) as f:
            page = f.read()
        title = headline(page)
        if not title:
            continue
        size = 76 if len(text(title)) < 40 else 62
        source = TEMPLATE.format(icon=icon, kicker=kicker(page), headline=title, slug=slug, size=size)
        image = os.path.join(out_dir, slug.replace("/", "-") + ".png")
        with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as tmp:
            tmp.write(source)
        subprocess.run([CHROME, "--headless", "--hide-scrollbars", f"--screenshot={image}",
                        "--window-size=1200,630", "--virtual-time-budget=5000", f"file://{tmp.name}"], capture_output=True, check=True)
        os.unlink(tmp.name)
        url = f"{BASE}/images/og/{os.path.basename(image)}"
        page = re.sub(r'(<meta property="og:image" content=")[^"]*(")', rf"\g<1>{url}\g<2>", page)
        page = re.sub(r'(<meta name="twitter:image" content=")[^"]*(")', rf"\g<1>{url}\g<2>", page)
        if 'name="twitter:image"' not in page:
            page = page.replace("</head>", f'  <meta name="twitter:image" content="{url}">\n</head>', 1)
        with open(path, "w") as f:
            f.write(page)
        print(f"{slug}: {os.path.basename(image)}")


if __name__ == "__main__":
    main()
