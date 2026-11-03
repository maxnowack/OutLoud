"""Lists German videos (the category tree) on Wikimedia Commons with a free licence, 2-60 min, and their 480p transcode.
usage: commons_de.py OUT_JSON"""
import json, sys, time, urllib.error, urllib.request, urllib.parse
UA = {"User-Agent": "outloud-lipreading-research/0.1 (non-commercial; one-off dataset)"}
def api(**p):
    p.update(format="json")
    u = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(p)
    for wait in (5, 20, 60, 120):
        try:
            time.sleep(1)
            return json.load(urllib.request.urlopen(urllib.request.Request(u, headers=UA)))
        except urllib.error.HTTPError as e:
            if e.code != 429: raise
            time.sleep(wait)
    raise SystemExit("rate limited")
files, cont = [], {}
while True:
    d = api(action="query", generator="search", gsrsearch='filetype:video deepcat:"Videos in German"',
            gsrnamespace=6, gsrlimit=50, prop="videoinfo", viprop="size|url|extmetadata|derivatives", **cont)
    for p in d.get("query", {}).get("pages", {}).values():
        vi = (p.get("videoinfo") or [{}])[0]
        lic = vi.get("extmetadata", {}).get("LicenseShortName", {}).get("value", "")
        dur = float(vi.get("duration", 0) or 0)
        if not (120 < dur < 3600) or not (lic.startswith("CC BY") or lic == "Public domain"):
            continue
        if "NC" in lic or "ND" in lic:
            continue
        der = [x for x in vi.get("derivatives", []) if x.get("transcodekey", "").startswith("480p")]
        url = der[0]["src"] if der else vi.get("url")
        files.append({"title": p["title"], "seconds": dur, "licence": lic, "url": url,
                      "page": vi.get("descriptionurl")})
    if "continue" not in d: break
    cont = d["continue"]
json.dump(files, open(sys.argv[1], "w"), ensure_ascii=False, indent=1)
print(len(files), round(sum(f["seconds"] for f in files) / 3600, 1), "h")
