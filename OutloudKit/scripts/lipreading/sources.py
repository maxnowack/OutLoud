"""SOURCES.md for the German model: the Commons videos that gave samples, with authors and licences.

usage: sources.py LIST.json OUT.md HARVEST_LOG ...
Reads the harvest logs' lines "<id> <url>" and "<id> <n> pieces: kept <k>, ..." (harvest.sh).
"""
import hashlib, html, json, re, sys, time, urllib.error, urllib.parse, urllib.request

UA = {"User-Agent": "outloud-lipreading-research/0.1 (non-commercial; one-off dataset)"}
listing, out, logs = sys.argv[1], sys.argv[2], sys.argv[3:]
by_id = {hashlib.sha1(f["url"].encode()).hexdigest()[:12]: f for f in json.load(open(listing))}
kept = {}
for log in logs:
    for line in open(log):
        m = re.match(r"(\w{12}) \d+ pieces: kept (\d+)", line)
        if m and int(m[2]) > 0:
            kept[m[1]] = int(m[2])

def authors(titles):
    """Artist of each file, fifty titles a request, waiting out the API's rate limit."""
    found = {}
    for i in range(0, len(titles), 50):
        u = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(dict(
            action="query", titles="|".join(titles[i:i + 50]), prop="imageinfo", iiprop="extmetadata",
            format="json"))
        for wait in (5, 30, 60, 120, 300):
            try:
                d = json.load(urllib.request.urlopen(urllib.request.Request(u, headers=UA)))
                break
            except urllib.error.HTTPError as e:
                if e.code != 429: raise
                time.sleep(wait)
        else:
            raise SystemExit("rate limited")
        for p in d["query"]["pages"].values():
            artist = (p.get("imageinfo") or [{}])[0].get("extmetadata", {}).get("Artist", {}).get("value", "unknown")
            found[p["title"]] = html.unescape(re.sub(r"<[^>]+>", "", artist)).strip()
        time.sleep(1)
    return found

videos = sorted(kept.items(), key=lambda x: by_id[x[0]]["title"])
artist = authors([by_id[id]["title"] for id, _ in videos])
rows = []
for id, count in videos:
    f = by_id[id]
    rows.append(f"| [{f['title'][5:]}]({f['page']}) | {artist.get(f['title'], 'unknown')} | {f['licence']} | {count} |")
open(out, "w").write(
    "# Sources of the German lip-reading model\n\n"
    "Six-second mouth crops of these videos from Wikimedia Commons, labelled by Parakeet, trained\n"
    "the German decoder; the videos themselves were deleted after cropping.\n\n"
    "| Video | Author | Licence | Samples |\n| --- | --- | --- | --- |\n" + "\n".join(rows) + "\n")
print(len(rows), "videos,", sum(kept.values()), "samples")
