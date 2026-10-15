#!/usr/bin/env python3
"""Tells IndexNow search engines (Bing and others) about every URL in the sitemaps.

    python3 site/_build/indexnow.py   # after deploying from main
"""
import glob
import json
import os
import re
import urllib.request

ROOT = os.path.join(os.path.dirname(__file__), "..")
KEY = "87bd3611a26cd93ca94b408e3da7c168"

urls = []
for path in sorted(glob.glob(os.path.join(ROOT, "sitemap*.xml"))):
    with open(path) as f:
        # A sitemap index lists other sitemaps, not pages.
        urls += [u for u in re.findall(r"<loc>(.*?)</loc>", f.read()) if not u.endswith(".xml")]
body = json.dumps({"host": "greenroomformac.com", "key": KEY,
                   "keyLocation": f"https://greenroomformac.com/{KEY}.txt", "urlList": urls}).encode()
request = urllib.request.Request("https://api.indexnow.org/indexnow", data=body,
                                 headers={"Content-Type": "application/json; charset=utf-8"})
with urllib.request.urlopen(request) as response:
    print(f"IndexNow: {response.status} for {len(urls)} URLs")
