"""Builds site/fix/*.html and site/sitemap-fix.xml from fix_data.py.

Run from anywhere: python3 site/_build/fix.py
"""

import html
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True  # Keep __pycache__ out of the published site folder.
from fix_data import APPS, PAGES  # noqa: E402

SITE = Path(__file__).resolve().parent.parent
OUT = SITE / "fix"
BASE = "https://greenroomformac.com"
DATE = "2026-10-14"

DEVICE_WORD = {"camera": "camera", "microphone": "microphone", "audio": "sound"}
DEVICE_LABEL = {"camera": "Camera", "microphone": "Microphone", "audio": "Sound"}
TOOL = {
    "camera": ("/webcam-test", "Webcam test", "Live preview, resolution, frame rate, and lighting."),
    "microphone": ("/mic-test", "Microphone test", "Live meter, then hear yourself back."),
    "audio": ("/speaker-test", "Speaker test", "Left, right, and a sweep to check every speaker."),
}
DOWNLOAD = "https://github.com/coreyhaines31/greenroom/releases/latest"
ARROW = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11m-5-5 5 5 5-5M5 20h14"/></svg>'
WARN = '<svg viewBox="0 0 20 18" aria-hidden="true"><path class="warn-fill solid" d="M10 1.6 18.6 16.4H1.4Z"/><path class="warn-mark" d="M10 6.6v4.6M10 13.4v.4"/></svg>'

# Copied from site/index.html (anchors made absolute, as the other subpages do).
NAV = """  <header class="nav">
    <div class="wrap">
      <a class="brand" href="/"><img src="/images/icon.png" alt="" width="30" height="30"> Green Room</a>
      <nav>
        <a href="/#how">How it works</a>
        <details class="menu"><summary>Free tests</summary><div class="menu-list"><span>Test in your browser</span><a href="/mic-test">Microphone test</a><a href="/webcam-test">Webcam test</a><a href="/speaker-test">Speaker test</a><span>Mac guides</span><a href="/mac-microphone-not-working">Mac microphone not working</a><a href="/mac-camera-not-working">Mac camera not working</a><a href="/how-to-test-microphone-on-mac">How to test your mic on a Mac</a></div></details>
        <a href="https://github.com/coreyhaines31/greenroom">GitHub</a>
        <a class="pill" href="https://github.com/coreyhaines31/greenroom/releases/latest">Download</a>
      </nav>
    </div>
  </header>"""

FOOTER = """  <footer>
    <div class="wrap">
      <div class="footer-links">
        <div><b>Free tests</b><a href="/mic-test">Microphone test</a><a href="/webcam-test">Webcam test</a><a href="/speaker-test">Speaker test</a></div>
        <div><b>Mac guides</b><a href="/mac-microphone-not-working">Mac microphone not working</a><a href="/mac-camera-not-working">Mac camera not working</a><a href="/how-to-test-microphone-on-mac">How to test your mic on a Mac</a></div>
        <div><b>Green Room</b><a href="/#how">How it works</a><a href="/#faq">Questions</a><a href="https://github.com/coreyhaines31/greenroom/releases/latest">Download</a></div>
      </div>
      <span>© 2026 Corey Haines · Source available under <a href="https://github.com/coreyhaines31/greenroom/blob/main/LICENSE">FSL-1.1-MIT</a></span>
      <span><a href="https://github.com/coreyhaines31/greenroom">GitHub</a> · <a href="https://github.com/coreyhaines31/greenroom/issues">Report a bug</a> · Also by Corey: <a href="https://wifiorisp.com">WiFi or ISP</a>, <a href="https://midnightoil.app">Midnight Oil</a></span>
    </div>
  </footer>"""


def text(fragment):
    """Plain text for JSON-LD and meta tags."""
    return html.unescape(re.sub(r"<[^>]+>", "", fragment))


def short(app):
    return app.get("short", app["name"])


def head(title, desc, url, graph, og_type="article"):
    ld = json.dumps({"@context": "https://schema.org", "@graph": graph}, ensure_ascii=False)
    t, d = html.escape(title), html.escape(desc)
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{t} · Green Room</title>
  <meta name="description" content="{d}">
  <meta property="og:title" content="{t}">
  <meta property="og:description" content="{d}">
  <meta property="og:image" content="{BASE}/images/og.png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:url" content="{url}">
  <meta property="og:type" content="{og_type}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="theme-color" content="#f5f5f7">
  <link rel="icon" href="/images/icon.png">
  <link rel="apple-touch-icon" href="/images/icon.png">
  <link rel="canonical" href="{url}">
  <link rel="stylesheet" href="/site.css">
  <link rel="stylesheet" href="/fix/fix.css">
  <script src="/nav.js" defer></script>
  <script type="application/ld+json">{ld}</script>
  <script src="https://cdn.usefathom.com/script.js" data-site="WDVXMJRM" defer></script>
</head>
<body>
{NAV}
"""


def breadcrumb(items):
    return {
        "@type": "BreadcrumbList",
        "itemListElement": [
            {"@type": "ListItem", "position": i + 1, "name": name, "item": url}
            for i, (name, url) in enumerate(items)
        ],
    }


def mac_checks(page, app):
    """The shared Mac checks, in order, for this app and device."""
    device, perm, name = page["device"], app["perm"], app["name"]
    steps = []
    if device in ("camera", "microphone"):
        pane = "Camera" if device == "camera" else "Microphone"
        if perm == "browser":
            steps.append((
                "Allow your browser on your Mac.",
                f"Choose Apple menu › System Settings › Privacy & Security › {pane}, and turn on the browser you use for {short(app)}, like Google Chrome, Firefox, or Edge. Quit and reopen the browser after."))
        elif perm:
            note = f" {app['perm_note']}" if app.get("perm_note") else ""
            steps.append((
                f"Allow {name} on your Mac.",
                f"Choose Apple menu › System Settings › Privacy & Security › {pane}, and turn on {perm}.{note} If it's already on, turn it off and on again. Quit and reopen {short(app)} after."))
    if device == "camera":
        extra = " and that FaceTime isn't limited" if page["app"] == "facetime" else ""
        steps.append((
            "Check Screen Time.",
            f"If you use Screen Time, open System Settings › Screen Time › Content & Privacy, then App Restrictions, and make sure Camera is allowed{extra}."))
        if page["app"] != "facetime":
            steps.append((
                "Watch for Continuity Camera.",
                f"Your Mac can switch to your iPhone's camera when the phone is nearby. If {short(app)} shows your phone's view, or a camera you didn't expect, pick your Mac's camera in {short(app)}."))
        if app.get("shared_cam"):
            steps.append((
                "Close other video apps.",
                f"{name}'s own help says to close other apps that might be using the camera, like Photo Booth or another call app, then try again."))
        steps.append((
            "Reconnect an external camera.",
            "Unplug a USB webcam or capture card and plug it back in. Try another port, and skip the hub or dock if you can. To see whether your Mac detects it, hold Option, choose Apple menu › System Information, and look under Camera."))
    elif device == "microphone":
        steps.append((
            "Check your Mac's input.",
            "Open System Settings › Sound and click Input. Select your mic, make sure the Input volume slider isn't at zero, and watch the level move when you talk."))
        steps.append((
            "Check the mic itself.",
            "Look for a mute button, a mute light, or a gain knob turned all the way down. Unplug a USB mic and plug it back in, try another port, and skip the hub if you can."))
        steps.append((
            "Watch for Bluetooth call mode.",
            f"When {short(app)} turns on the mic in AirPods or another Bluetooth headset, the headset switches to call mode and your voice drops to phone quality. If you sound muffled, use your Mac's mic or a USB mic, and keep the headset for listening."))
    else:
        steps.append((
            "Check your Mac's output.",
            "Open System Settings › Sound and click Output. Select the speakers or headphones you're listening on, raise the Output volume, and make sure Mute is off."))
        steps.append((
            "Reconnect Bluetooth headphones.",
            "AirPods can switch to your iPhone or iPad when you use it. Connect them to this Mac from the Sound section of Control Center or Bluetooth settings, then pick them again."))
        steps.append((
            "Reconnect wired speakers.",
            "Unplug USB speakers or a headset and plug them back in, or try another port. A display with speakers can take over the sound when you plug it in."))
    return steps


def mockup(page, app):
    """A Green Room panel card for this device, built from site.css classes."""
    proc = html.escape(app["proc"])
    if page["device"] == "camera":
        label = "A Green Room panel card. Cam Link 4K isn't connected: not plugged in, last seen today at 9:12 AM. Your Mac doesn't see it on USB at all. Check the cable and hub, or try another port."
        return f"""<div class="meters" role="img" aria-label="{html.escape(label)}">
            <div class="meter-card">
              <span class="popup static">FaceTime HD Camera · Built-in<i></i></span>
              <div class="cam" aria-hidden="true"><span class="cam-lamp"></span><span class="cam-frame"></span><span class="cam-plant"></span><span class="cam-neck"></span><span class="cam-body"></span><span class="cam-head"></span></div>
            </div>
            <div class="meter-card">
              <div class="missing"><b>Cam Link 4K</b><span class="orange">Not plugged in · last seen today 9:12 AM</span><span class="muted">Your Mac doesn't see it on USB at all. Check the cable and hub, or try another port.</span></div>
            </div>
          </div>"""
    if page["device"] == "microphone":
        label = f"A Green Room microphone card. {app['proc']} is using MacBook Pro Microphone, not Shure MV7, with a Switch to Shure MV7 button."
        return f"""<div class="meters" role="img" aria-label="{html.escape(label)}">
            <div class="meter-card">
              <span class="popup static">Shure MV7 · USB<i></i></span>
              <div class="meter"><span></span></div>
              <p class="m-warn">{WARN}{proc} is using MacBook Pro Microphone, not Shure MV7.</p>
              <span class="mac-btn">Switch to Shure MV7</span>
            </div>
          </div>"""
    label = f"Two Green Room cards. {app['proc']} is using AirPods Pro, not Studio Monitors, with a Switch button. AirPods Pro is in call mode because {app['proc']} turned on its mic."
    return f"""<div class="meters" role="img" aria-label="{html.escape(label)}">
            <div class="meter-card">
              <span class="popup static">Studio Monitors · USB<i></i></span>
              <p class="m-warn">{WARN}{proc} is using AirPods Pro, not Studio Monitors.</p>
              <span class="mac-btn">Switch to Studio Monitors</span>
            </div>
            <div class="meter-card call-mode">
              <p class="cm-title">{WARN}AirPods Pro is in call mode</p>
              <p class="cm-body">{proc} turned on its mic, so your voice and everything you hear drop to phone quality.</p>
              <span class="mac-btn">Use MacBook Pro Microphone</span>
            </div>
          </div>"""


def green_room(page, app):
    name, proc, device = short(app), html.escape(app["proc"]), page["device"]
    browser = f" For {name}, that's your browser, like {proc}." if app["perm"] == "browser" else ""
    if device == "camera":
        h = f"On a Mac? Green Room checks your camera before {name} does."
        p = ("Click the icon next to the clock for a live preview of the camera your Mac suggests to apps. "
             "When a camera you usually use goes missing, it tells you whether your Mac sees it on USB at all, or sees it but can't use it. "
             f"A green dot shows when another app already has a camera open.")
    elif device == "microphone":
        h = f"On a Mac? See which mic {name} is really using."
        p = (f"{name} keeps its own mic choice, so your Mac can look right while the call uses the wrong one. "
             f"Green Room shows which app has each mic open, and warns you when {proc} isn't using your setup.{browser} "
             "One click switches your Mac back, and it flags a mic that's muted, at zero, or silent.")
    else:
        h = f"On a Mac? See where {name}'s sound is really going."
        p = (f"Green Room shows which app has each speaker open, and warns you when {proc} is playing somewhere that isn't your setup.{browser} "
             "When AirPods drop into call mode, it tells you and offers your Mac's own mic so the sound comes back. One click puts your setup back.")
    if page["app"] == "obs":
        p += " When OBS starts recording, Green Room also checks your camera's resolution and frame rate, your mic, disk space, and power, and speaks up only if something would spoil the take."
    return f"""    <section class="article">
      <div class="wrap narrow">
        <div class="gr-card">
          <div>
            <img src="/images/icon.png" alt="" width="52" height="52">
            <h2>{h}</h2>
            <p>{p} Free, with no account.</p>
            <div class="actions">
              <a class="pill big" href="{DOWNLOAD}">{ARROW}Download free</a>
              <a class="pill ghost" href="/">See how it works</a>
            </div>
          </div>
          {mockup(page, app)}
        </div>
      </div>
    </section>
"""


def ol(steps):
    return "\n".join(f"          <li><b>{b}</b>{t}</li>" for b, t in steps)


def related(page):
    same_app = [p for p in PAGES if p["app"] == page["app"] and p is not page]
    same_device = [p for p in PAGES if p["device"] == page["device"] and p["app"] != page["app"]]
    picks = (same_app + same_device)[:6]
    cards = "\n".join(
        f'          <a href="/fix/{p["slug"]}"><b>{html.escape(p["h1"].rstrip("?"))}</b><span>{html.escape(text(p["lede"]).split(". ")[0].rstrip(".") + ".")}</span></a>'
        for p in picks)
    return f"""        <h2>Other fixes</h2>
        <div class="tool-links">
{cards}
        </div>
        <p><a href="/fix">See every app and device</a></p>"""


def render(page):
    app = APPS[page["app"]]
    name, device = app["name"], page["device"]
    url = f"{BASE}/fix/{page['slug']}"
    app_steps, mac_steps = page["steps"], mac_checks(page, app)
    tool_url, tool_name, tool_desc = TOOL[device]
    others = [TOOL[d] for d in TOOL if d != device]

    howto = {
        "@type": "HowTo",
        "name": f"How to fix {page['h1'].rstrip('?')} on a Mac",
        "description": page["desc"],
        "step": [
            {"@type": "HowToStep", "position": i + 1, "name": text(b).rstrip("."), "text": text(t)}
            for i, (b, t) in enumerate(app_steps + mac_steps)
        ],
    }
    faq = {
        "@type": "FAQPage",
        "mainEntity": [
            {"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}}
            for q, a in page["faqs"]
        ],
    }
    crumbs = breadcrumb([("Home", f"{BASE}/"), ("Fix", f"{BASE}/fix"), (page["h1"].rstrip("?"), url)])
    article = {
        "@type": "Article", "headline": page["title"], "description": page["desc"], "url": url,
        "datePublished": DATE, "dateModified": DATE, "image": f"{BASE}/images/og.png",
        "author": {"@type": "Person", "name": "Corey Haines", "url": "https://corey.co"},
        "publisher": {"@type": "Organization", "name": "Green Room",
                      "logo": {"@type": "ImageObject", "url": f"{BASE}/images/icon.png"}},
    }

    extra = "\n".join(f"        <h3>{h}</h3>\n        <p>{p}</p>" for h, p in page["extra"])
    faqs = "\n".join(
        f"        <details><summary>{html.escape(q)}</summary><p>{html.escape(a)}</p></details>"
        for q, a in page["faqs"])
    other_tools = "\n".join(f'          <a href="{u}"><b>{n}</b><span>{d}</span></a>' for u, n, d in others)
    word = DEVICE_WORD[device]

    return head(page["title"], page["desc"], url, [article, howto, faq, crumbs]) + f"""
  <main>
    <section class="sub-hero">
      <div class="wrap narrow">
        <p class="kicker"><span class="dot"></span><a class="crumb" href="/fix">Fix</a> · {html.escape(name)} on a Mac</p>
        <h1>{html.escape(page['h1'])} <em>{html.escape(page['em'])}</em></h1>
        <p class="lede">{page['lede']}</p>
      </div>
    </section>

    <section class="article">
      <div class="wrap narrow prose">
        <div class="tldr"><p><b>Quick check first:</b> {page['quick']}</p></div>

        <h2>Fix it in {html.escape(short(app))}</h2>
        <ol class="fixes">
{ol(app_steps)}
        </ol>
{extra}

        <h2>Then check your Mac</h2>
        <p>If {html.escape(short(app))} looks right and the {word} still doesn't work, go through these in order.</p>
        <ol class="fixes">
{ol(mac_steps)}
        </ol>

        <h2>Test it outside {html.escape(short(app))}</h2>
        <p>The free <a href="{tool_url}">{tool_name.lower()}</a> runs in your browser, with nothing to install. If your {word} works there, your Mac and the hardware are fine, and the fix is in {html.escape(short(app))}'s settings above.</p>
        <div class="tool-links">
          <a href="{tool_url}"><b>{tool_name}</b><span>{tool_desc}</span></a>
{other_tools}
        </div>
      </div>
    </section>

{green_room(page, app)}
    <section class="faq after-article">
      <div class="wrap narrow">
        <h2>Questions</h2>
{faqs}
      </div>
    </section>

    <section class="article">
      <div class="wrap narrow prose">
{related(page)}
      </div>
    </section>
  </main>

{FOOTER}
</body>
</html>
"""


def render_hub():
    url = f"{BASE}/fix"
    title = "Fix Your Camera, Mic, or Sound in Any App on a Mac"
    desc = "Step by step fixes for Zoom, Teams, Google Meet, Discord, FaceTime, Slack, Webex, and OBS on a Mac, checked against each app's own help."
    by_app = {}
    for p in PAGES:
        by_app.setdefault(p["app"], []).append(p)
    cards = []
    for key, pages in by_app.items():
        app = APPS[key]
        pages = sorted(pages, key=lambda p: list(DEVICE_LABEL).index(p["device"]))
        links = "".join(
            f'<a href="/fix/{p["slug"]}">{DEVICE_LABEL[p["device"]]}<span aria-hidden="true">›</span></a>' for p in pages)
        cards.append(f'          <div class="fix-app"><h2>{html.escape(app["name"])}</h2><div class="fix-links">{links}</div></div>')
    item_list = {
        "@type": "ItemList",
        "itemListElement": [
            {"@type": "ListItem", "position": i + 1, "url": f"{BASE}/fix/{p['slug']}", "name": p["h1"].rstrip("?")}
            for i, p in enumerate(PAGES)
        ],
    }
    crumbs = breadcrumb([("Home", f"{BASE}/"), ("Fix", url)])
    page = {"@type": "CollectionPage", "name": title, "description": desc, "url": url}
    return head(title, desc, url, [page, item_list, crumbs], og_type="website") + f"""
  <main>
    <section class="sub-hero">
      <div class="wrap narrow">
        <p class="kicker"><span class="dot"></span>App fixes · macOS 14 Sonoma and later</p>
        <h1>Fix your camera, mic, or sound <em>in any app.</em></h1>
        <p class="lede">Pick the app and what's broken. Each fix starts with that app's own settings, then the Mac checks, in the order to try them.</p>
      </div>
    </section>

    <section class="article">
      <div class="wrap">
        <div class="fix-grid">
{chr(10).join(cards)}
        </div>
      </div>
    </section>

    <section class="article">
      <div class="wrap narrow prose">
        <h2>Broken everywhere, not just one app?</h2>
        <p>If your camera or mic fails in every app, start with the Mac itself.</p>
        <div class="tool-links">
          <a href="/mac-camera-not-working"><b>Mac camera not working</b><span>Permissions, Screen Time, and cables, in order.</span></a>
          <a href="/mac-microphone-not-working"><b>Mac microphone not working</b><span>The fixes, in the order to try them.</span></a>
          <a href="/speaker-test"><b>Speaker test</b><span>Left, right, and a sweep to check every speaker.</span></a>
        </div>
      </div>
    </section>

    <section class="article">
      <div class="wrap narrow">
        <div class="gr-card">
          <div>
            <img src="/images/icon.png" alt="" width="52" height="52">
            <h2>On a Mac? Green Room shows what your call is really using.</h2>
            <p>Apps keep their own device choices, so your Mac can look right while the call uses the wrong mic. Green Room shows which app has each mic and speaker open, warns you when it isn't your setup, and puts the fix one click away. Free, with no account.</p>
            <div class="actions">
              <a class="pill big" href="{DOWNLOAD}">{ARROW}Download free</a>
              <a class="pill ghost" href="/">See how it works</a>
            </div>
          </div>
          {mockup({"device": "microphone"}, APPS["zoom"])}
        </div>
      </div>
    </section>
  </main>

{FOOTER}
</body>
</html>
"""


def sitemap():
    urls = [f"{BASE}/fix"] + [f"{BASE}/fix/{p['slug']}" for p in PAGES]
    rows = "\n".join(f"  <url>\n    <loc>{u}</loc>\n    <lastmod>{DATE}</lastmod>\n  </url>" for u in urls)
    return f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{rows}\n</urlset>\n'


def main():
    OUT.mkdir(exist_ok=True)
    for page in PAGES:
        (OUT / f"{page['slug']}.html").write_text(render(page))
    (OUT / "index.html").write_text(render_hub())
    (SITE / "sitemap-fix.xml").write_text(sitemap())
    print(f"Wrote {len(PAGES)} fix pages, the hub, and sitemap-fix.xml")


if __name__ == "__main__":
    main()
