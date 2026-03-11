"""
FIX BAD RECIPE IMAGES – PEXELS EDITION
========================================
Uses the Pexels API (free, 200 req/hour) to replace suspicious/bad recipe
images with professional food photography.

Get a FREE key in ~2 minutes:
  1. Go to  https://www.pexels.com/api/
  2. Sign up / Log in
  3. Copy your API key

Usage (from backend/) :
    python ../scripts/fix_bad_images_pexels.py --key YOUR_PEXELS_KEY
    python ../scripts/fix_bad_images_pexels.py --key YOUR_KEY --dry-run
    python ../scripts/fix_bad_images_pexels.py --key YOUR_KEY --reset
"""

import os, sys, time, json, argparse, requests
from datetime import datetime

# ── env / deps ───────────────────────────────────────────────────────────────
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from dotenv import load_dotenv
    _env = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "backend", ".env")
    if os.path.exists(_env):
        load_dotenv(_env)
except ImportError:
    pass

try:
    import psycopg2, psycopg2.extras
except ImportError:
    print("pip install psycopg2-binary"); sys.exit(1)

# ── constants ────────────────────────────────────────────────────────────────
PEXELS_URL  = "https://api.pexels.com/v1/search"
CHECKPOINT  = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pexels_fix_checkpoint.json")
API_DELAY   = 19        # Pexels free: 200 req/hour → 1 req/18 s, use 19 for safety
RATE_WAIT   = 60        # Wait when rate-limited

# ── bad-image heuristics (same as report generator) ─────────────────────────
BAD_PATTERNS = [
    "placeholder", "fporecipe", "recipe-1-5.webp",
    "fl.yelpcdn.com", "dreamstime.com",
    "hq720.jpg?sqp=", "hqdefault.jpg", "sddefault.jpg", "maxresdefault.jpg",
    "ytimg.com", "snapcalorie-webflow", "cpcdn.com/steps",
    "img-global.cpcdn.com/steps", "tripadvisor.com",
    "route-fifty.com", "slideserve.com", "static.flickr.com",
]

def is_bad(url):
    if not url:
        return True
    lower = url.lower()
    return any(p.lower() in lower for p in BAD_PATTERNS)

# ── smarter query builder ────────────────────────────────────────────────────
STRIP_WORDS = {
    "recipe", "recipes", "authentic", "traditional", "homemade",
    "easy", "quick", "simple", "best", "delicious", "classic",
    "my", "the", "a", "an", "with", "and", "or", "from",
    "minute", "minutes", "step", "ingredient", "ingredients",
}

def smart_query(name: str) -> str:
    tokens = name.split()
    # Drop parenthetical alternate names e.g. "(Chummus)"
    clean, depth = [], 0
    for t in tokens:
        if "(" in t: depth += 1
        if depth == 0: clean.append(t)
        if ")" in t: depth -= 1
    filtered = [t.strip("(),;:.") for t in clean
                if t.lower().strip("(),;:.") not in STRIP_WORDS and t.strip("(),;:.")]
    core = " ".join(filtered[:4])
    return f"{core} food"

# ── Pexels search ────────────────────────────────────────────────────────────
def search_pexels(query: str, key: str) -> str | None:
    headers = {"Authorization": key}
    params  = {
        "query": query,
        "per_page": 5,
        "orientation": "landscape",
        "size": "large",
    }
    try:
        r = requests.get(PEXELS_URL, headers=headers, params=params, timeout=10)
    except requests.RequestException as e:
        print(f"    ⚠️  Network: {e}"); return None

    if r.status_code == 429:
        print(f"    ⏳  Rate-limit – waiting {RATE_WAIT}s…")
        time.sleep(RATE_WAIT)
        try:
            r = requests.get(PEXELS_URL, headers=headers, params=params, timeout=10)
        except:
            return None

    if r.status_code == 401:
        print("    ❌  Invalid API key (401)."); return None
    if r.status_code != 200:
        print(f"    ⚠️  HTTP {r.status_code}"); return None

    photos = r.json().get("photos", [])
    if not photos:
        return None

    # Use the "large2x" src which is typically 940px wide – good quality
    src = photos[0].get("src", {})
    return src.get("large2x") or src.get("large") or src.get("original")

# ── checkpoint helpers ───────────────────────────────────────────────────────
def load_cp():
    if os.path.exists(CHECKPOINT):
        with open(CHECKPOINT, encoding="utf-8") as f:
            return json.load(f)
    return {"fixed": [], "skipped": [],
            "stats": {"fixed": 0, "skipped": 0},
            "started": datetime.now().isoformat()}

def save_cp(cp):
    cp["updated"] = datetime.now().isoformat()
    with open(CHECKPOINT, "w", encoding="utf-8") as f:
        json.dump(cp, f, indent=2, ensure_ascii=False)

# ── main ─────────────────────────────────────────────────────────────────────
def run(key, limit, dry_run, reset):
    db_url = os.environ.get("DATABASE_URL", "")
    if not db_url:
        print("❌  DATABASE_URL not set."); sys.exit(1)
    db_url = db_url.replace("postgres://", "postgresql://", 1)

    conn = psycopg2.connect(db_url)
    cur  = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

    cur.execute("SELECT id::text, name, cuisine, image_url FROM recipes ORDER BY name")
    all_rows = cur.fetchall()

    bad_rows = [r for r in all_rows if is_bad(r["image_url"])]
    if limit:
        bad_rows = bad_rows[:limit]

    cp = {} if reset else load_cp()
    if reset:
        cp = {"fixed": [], "skipped": [],
              "stats": {"fixed": 0, "skipped": 0},
              "started": datetime.now().isoformat()}

    done_ids   = set(cp.get("fixed", []) + cp.get("skipped", []))
    remaining  = [r for r in bad_rows if r["id"] not in done_ids]

    print("=" * 65)
    print("  CUISINEE ✦ FIX BAD IMAGES (Pexels)")
    print("=" * 65)
    print(f"  Total bad/suspicious : {len(bad_rows)}")
    print(f"  Already done         : {len(done_ids)}")
    print(f"  To process now       : {len(remaining)}")
    print(f"  Dry run              : {dry_run}")
    print("=" * 65)
    print()

    for idx, row in enumerate(remaining, 1):
        rid  = row["id"]
        name = row["name"]
        q    = smart_query(name)
        print(f"[{idx:>3}/{len(remaining)}] 🔍  {name}")
        print(f"         query: \"{q}\"")

        url = search_pexels(q, key)

        if not url:
            # Shorter fallback: first 2–3 content words
            fb_tokens = [t.strip("(),;:.") for t in name.split()
                         if t.lower().strip("(),;:.") not in STRIP_WORDS][:3]
            fb = " ".join(fb_tokens) + " food"
            print(f"         ↩️  fallback: \"{fb}\"")
            url = search_pexels(fb, key)

        if url:
            print(f"         ✅  {url[:80]}…")
            if not dry_run:
                cur.execute(
                    "UPDATE recipes SET image_url=%s WHERE id=%s::uuid",
                    (url, rid),
                )
                conn.commit()
            cp["fixed"].append(rid)
            cp["stats"]["fixed"] += 1
        else:
            print(f"         ❌  No result – keeping old image.")
            cp["skipped"].append(rid)
            cp["stats"]["skipped"] += 1

        save_cp(cp)
        time.sleep(API_DELAY)

    cur.close()
    conn.close()

    print()
    print("=" * 65)
    print("  DONE")
    print(f"  ✅  Fixed   : {cp['stats']['fixed']}")
    print(f"  ❌  Skipped : {cp['stats']['skipped']}")
    if dry_run:
        print("\n  ⚠️  DRY-RUN – nothing written to DB.")
    print("=" * 65)

def main():
    p = argparse.ArgumentParser(description="Fix bad recipe images using Pexels API.")
    p.add_argument("--key",   default=os.getenv("PEXELS_API_KEY", ""),
                   help="Pexels API key (or set PEXELS_API_KEY env var)")
    p.add_argument("--limit", type=int, default=0, help="0 = all bad recipes")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--reset",   action="store_true", help="Ignore checkpoint and restart")
    args = p.parse_args()

    if not args.key:
        print("❌  No Pexels API key.")
        print()
        print("  Get a free key in ~2 minutes:")
        print("    1. Go to  https://www.pexels.com/api/")
        print("    2. Sign up / Log in")
        print("    3. Copy your API key")
        print()
        print("  Then run:")
        print("    python ../scripts/fix_bad_images_pexels.py --key YOUR_KEY")
        sys.exit(1)

    run(args.key, args.limit or None, args.dry_run, args.reset)

if __name__ == "__main__":
    main()
