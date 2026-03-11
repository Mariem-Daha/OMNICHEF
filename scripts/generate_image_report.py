"""
RECIPE IMAGE VISUAL REPORT
===========================
Generates an HTML file showing every recipe name alongside its current
image so you can visually audit which photos are wrong/mismatched.

Also flags known bad patterns:
  • Placeholder images (recipeland, foodgeeks, cpcdn placeholders, etc.)
  • YouTube thumbnails (hq720, sqp= in URL)
  • Yelp photos (fl.yelpcdn.com)
  • Dreamstime stock (dreamstime.com)
  • Very generic filenames that suggest a mismatch

Usage (run from backend/) :
    python ../scripts/generate_image_report.py
    python ../scripts/generate_image_report.py --limit 200

Then open  scripts/recipe_image_report.html  in your browser.
"""

import os
import sys
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from dotenv import load_dotenv
    _env = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "backend", ".env")
    if os.path.exists(_env):
        load_dotenv(_env)
except ImportError:
    pass

import psycopg2
import psycopg2.extras

# ── Bad-image heuristics ────────────────────────────────────────────────────

BAD_PATTERNS = [
    "placeholder",
    "fporecipe",
    "recipe-1-5.webp",
    "fl.yelpcdn.com",
    "dreamstime.com",
    "hq720.jpg?sqp=",          # YouTube thumbnail
    "hqdefault.jpg",
    "sddefault.jpg",
    "maxresdefault.jpg",
    "ytimg.com",
    "snapcalorie-webflow",
    "cpcdn.com/steps",          # cpcdn step images (usually not dish photos)
    "img-global.cpcdn.com/steps",
    "tripadvisor.com",
    "/ad/",
    "advertis",
    "route-fifty.com",          # clearly irrelevant stock
    "slideserve.com",
    "imgur.com/vi/",
    "static.flickr.com",
    "blogspot.com",
    "wordpress.com",
]

def is_suspicious(url: str) -> bool:
    if not url:
        return True
    lower = url.lower()
    return any(p.lower() in lower for p in BAD_PATTERNS)


# ── HTML template ───────────────────────────────────────────────────────────

HTML_HEAD = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Recipe Image Audit – Cuisinee</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: system-ui, sans-serif; background: #f5f5f5; color: #222; }
  header { background: #1a1a2e; color: #fff; padding: 20px 30px; }
  header h1 { font-size: 1.5rem; }
  header p  { font-size: .85rem; opacity: .7; margin-top: 4px; }
  .stats { display:flex; gap:20px; padding:16px 30px; background:#fff;
           border-bottom:1px solid #e0e0e0; flex-wrap:wrap; }
  .stat  { background:#f0f0f0; border-radius:8px; padding:8px 16px; font-size:.85rem; }
  .stat b { font-size:1.1rem; display:block; }
  .grid  { display:grid;
           grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
           gap:14px; padding:20px 30px; }
  .card  { background:#fff; border-radius:10px; overflow:hidden;
           box-shadow:0 1px 4px rgba(0,0,0,.12); }
  .card.bad { outline: 3px solid #e53935; }
  .thumb { width:100%; height:160px; object-fit:cover; background:#ddd;
           display:block; }
  .thumb-broken { width:100%; height:160px; background:#eee;
                  display:flex; align-items:center; justify-content:center;
                  font-size:.75rem; color:#999; }
  .info  { padding:10px 12px; }
  .name  { font-size:.82rem; font-weight:600; line-height:1.35;
           margin-bottom:4px; }
  .cuisine { font-size:.72rem; color:#888; }
  .badge { display:inline-block; margin-top:6px; padding:2px 7px;
           border-radius:20px; font-size:.68rem; font-weight:700; }
  .badge.warn { background:#fff3e0; color:#e65100; }
  .badge.ok   { background:#e8f5e9; color:#2e7d32; }
  .badge.missing { background:#fce4ec; color:#c62828; }
  .url-box { font-size:.65rem; color:#aaa; word-break:break-all;
             padding:0 12px 8px; }
  .filter-bar { padding:12px 30px; background:#fff; border-bottom:1px solid #e0e0e0;
                display:flex; gap:10px; flex-wrap:wrap; align-items:center; }
  .filter-bar label { font-size:.85rem; cursor:pointer; }
  input[type=checkbox] { cursor:pointer; }
  input[type=text] { padding:6px 10px; border:1px solid #ccc; border-radius:6px;
                     font-size:.85rem; width:240px; }
</style>
</head>
<body>
<header>
  <h1>🍽 Cuisinee – Recipe Image Audit</h1>
  <p>Visual report generated — check every recipe photo below. Red border = suspicious image.</p>
</header>
"""

HTML_STATS = """\
<div class="stats">
  <div class="stat"><b>{total}</b>Total recipes</div>
  <div class="stat"><b style="color:#e53935">{bad}</b>Suspicious</div>
  <div class="stat"><b style="color:#c62828">{missing}</b>No image</div>
  <div class="stat"><b style="color:#2e7d32">{ok}</b>Looks OK</div>
</div>
"""

HTML_FILTER = """\
<div class="filter-bar">
  <span style="font-size:.85rem;font-weight:600">Filter:</span>
  <label><input type="checkbox" id="chkBad" onchange="applyFilter()" checked> Show suspicious only</label>
  <label><input type="checkbox" id="chkMissing" onchange="applyFilter()"> Show missing only</label>
  <input type="text" id="search" placeholder="Search recipe name…" oninput="applyFilter()">
</div>
<script>
function applyFilter(){
  var onlyBad = document.getElementById('chkBad').checked;
  var onlyMissing = document.getElementById('chkMissing').checked;
  var q = document.getElementById('search').value.toLowerCase();
  document.querySelectorAll('.card').forEach(function(c){
    var name = c.dataset.name || '';
    var bad  = c.dataset.bad === '1';
    var miss = c.dataset.missing === '1';
    var textOk = !q || name.includes(q);
    var stateOk = (!onlyBad && !onlyMissing) ||
                  (onlyBad && bad) ||
                  (onlyMissing && miss);
    c.style.display = (textOk && stateOk) ? '' : 'none';
  });
}
// Apply on load so only suspicious show up immediately
window.addEventListener('DOMContentLoaded', applyFilter);
</script>
"""

HTML_TAIL = """\
</div>
</body>
</html>
"""

CARD_TMPL = """\
<div class="card {cls}" data-name="{name_lower}" data-bad="{bad_flag}" data-missing="{miss_flag}">
  {img_html}
  <div class="info">
    <div class="name">{name}</div>
    <div class="cuisine">{cuisine}</div>
    <span class="badge {badge_cls}">{badge_txt}</span>
  </div>
  <div class="url-box">{url_short}</div>
</div>
"""


def make_card(name: str, cuisine: str, url: str) -> tuple[str, str]:
    """Returns (html, status) where status in 'ok'|'bad'|'missing'."""
    safe_name = name.replace('"', '&quot;').replace('<', '&lt;')
    safe_cuisine = (cuisine or "").replace('"', '&quot;')

    if not url:
        status = "missing"
        cls = "bad"
        img_html = '<div class="thumb-broken">❌ No image</div>'
        badge_cls, badge_txt = "missing", "NO IMAGE"
        url_short = ""
    elif is_suspicious(url):
        status = "bad"
        cls = "bad"
        img_html = f'<img class="thumb" src="{url}" loading="lazy" onerror="this.style.display=\'none\';this.nextSibling.style.display=\'flex\'" alt="">' \
                   '<div class="thumb-broken" style="display:none">⚠️ Broken</div>'
        badge_cls, badge_txt = "warn", "⚠ SUSPICIOUS"
        url_short = url[:80] + "…" if len(url) > 80 else url
    else:
        status = "ok"
        cls = ""
        img_html = f'<img class="thumb" src="{url}" loading="lazy" onerror="this.style.display=\'none\';this.nextSibling.style.display=\'flex\'" alt="">' \
                   '<div class="thumb-broken" style="display:none">⚠️ Broken</div>'
        badge_cls, badge_txt = "ok", "✓ OK"
        url_short = url[:80] + "…" if len(url) > 80 else url

    html = CARD_TMPL.format(
        cls=cls,
        name_lower=safe_name.lower(),
        bad_flag="1" if status == "bad" else "0",
        miss_flag="1" if status == "missing" else "0",
        img_html=img_html,
        name=safe_name,
        cuisine=safe_cuisine,
        badge_cls=badge_cls,
        badge_txt=badge_txt,
        url_short=url_short,
    )
    return html, status


def run(limit: int):
    db_url = os.environ.get("DATABASE_URL", "")
    if not db_url:
        print("❌  DATABASE_URL not set.")
        sys.exit(1)
    db_url = db_url.replace("postgres://", "postgresql://", 1)

    conn = psycopg2.connect(db_url)
    cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
    cur.execute(
        "SELECT name, cuisine, image_url FROM recipes ORDER BY name LIMIT %s",
        (limit,),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()

    print(f"Building report for {len(rows)} recipes…")

    cards_html = []
    counts = {"ok": 0, "bad": 0, "missing": 0}

    for row in rows:
        html, status = make_card(row["name"], row["cuisine"], row["image_url"])
        cards_html.append(html)
        counts[status] += 1

    out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "recipe_image_report.html")

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(HTML_HEAD)
        f.write(HTML_STATS.format(
            total=len(rows),
            bad=counts["bad"],
            missing=counts["missing"],
            ok=counts["ok"],
        ))
        f.write(HTML_FILTER)
        f.write('<div class="grid">\n')
        f.write("\n".join(cards_html))
        f.write(HTML_TAIL)

    print(f"\n✅  Report saved → {out_path}")
    print(f"   Total     : {len(rows)}")
    print(f"   Suspicious: {counts['bad']}")
    print(f"   Missing   : {counts['missing']}")
    print(f"   OK        : {counts['ok']}")
    print(f"\n   Open the file in your browser to review.")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--limit", type=int, default=500, help="Max recipes to include (default 500)")
    args = p.parse_args()
    run(args.limit)


if __name__ == "__main__":
    main()
