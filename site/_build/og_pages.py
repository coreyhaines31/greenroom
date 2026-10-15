#!/usr/bin/env python3
"""Renders a share image per page and points each page's og:image and twitter:image at it.

    python3 site/_build/og_pages.py

Each page's <h1> becomes the headline (its <em> or green part on the second line), and the
kicker above it the small label, on the same background and icon as the home page image. The
home page keeps images/og.png. Needs Google Chrome for rendering.
"""
import glob
import html
import os
import re
import subprocess
import tempfile

SITE = os.path.join(os.path.dirname(__file__), "..")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
BASE = "https://greenroomformac.com"

TEMPLATE = """<!doctype html><html><head><meta charset="utf-8"><style>
* {{ box-sizing: border-box; }}
html, body {{ margin: 0; width: 1200px; height: 630px; overflow: hidden; }}
body {{
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif; color: #1d1d1f;
  background: radial-gradient(620px 460px at 8% 0%, rgba(48, 209, 88, 0.22), transparent 70%),
    radial-gradient(640px 480px at 95% 100%, rgba(10, 132, 255, 0.16), transparent 70%), #f5f5f7;
  padding: 90px 96px; display: flex; flex-direction: column; justify-content: space-between;
}}
.brand {{ display: flex; align-items: center; gap: 16px; font-size: 30px; font-weight: 600; }}
.brand img {{ width: 64px; height: 64px; }}
.kicker {{ font-size: 22px; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; color: #6e6e73; }}
h1 {{ font-size: {size}px; line-height: 1.04; font-weight: 700; margin: 14px 0 0; letter-spacing: -0.04em; max-width: 1000px; }}
h1 em {{ color: #12884b; display: block; font-style: normal; }}
.url {{ font-size: 24px; color: #6e6e73; }}
</style></head><body>
<div class="brand"><img src="file://{icon}" alt=""> Green Room</div>
<div><div class="kicker">{kicker}</div><h1>{headline}</h1></div>
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
                        "--window-size=1200,630", f"file://{tmp.name}"], capture_output=True, check=True)
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
