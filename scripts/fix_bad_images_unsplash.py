"""
FIX BAD RECIPE IMAGES
======================
Re-fetches Unsplash images for recipes whose current image is suspicious
(YouTube thumbnail, Yelp photo, placeholder, Dreamstime, etc.).

Uses smarter, shorter search queries so Unsplash returns the right dish.

Usage (from backend/) :
    python ../scripts/fix_bad_images_unsplash.py --key YOUR_KEY
    python ../scripts/fix_bad_images_unsplash.py --key YOUR_KEY --dry-run
    python ../scripts/fix_bad_images_unsplash.py --key YOUR_KEY --limit 50
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
UNSPLASH_URL   = "https://api.unsplash.com/search/photos"
CHECKPOINT     = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fix_bad_checkpoint.json")
API_DELAY      = 78       # 50 req/hour max → 1 req / 72 s to stay safe
RATE_WAIT      = 120      # wait when 403 received

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
# Strip filler words so Unsplash focuses on the actual dish name.
STRIP_WORDS = {
    "recipe", "recipes", "authentic", "traditional", "homemade",
    "easy", "quick", "simple", "best", "delicious", "classic",
    "my", "the", "a", "an", "with", "and", "or", "from",
}

def smart_query(name: str) -> str:
    """Turn a long recipe name into a tight Unsplash food query."""
    tokens = name.split()
    # Remove parenthetical alternate names, e.g. "(Chummus)"
    clean = []
    depth = 0
    for t in tokens:
        if "(" in t:
            depth += 1
        if depth == 0:
            clean.append(t)
        if ")" in t:
            depth -= 1
    # Drop filler words
    filtered = [t for t in clean if t.lower().rstrip(".,;:") not in STRIP_WORDS]
    # Cap at 5 meaningful tokens
    core = " ".join(filtered[:5])
    return f"{core} food dish"

# ── Unsplash search ──────────────────────────────────────────────────────────
def search(query: str, key: str):
    headers = {"Authorization": f"Client-ID {key}", "Accept-Version": "v1"}
    params  = {"query": query, "per_page": 5, "orientation": "landscape",
                "content_filter": "high"}
    try:
        r = requests.get(UNSPLASH_URL, params=params, headers=headers, timeout=10)
    except requests.RequestException as e:
        print(f"    ⚠️  Network: {e}"); return None

    if r.status_code == 403:
        print(f"    ⏳  Rate-limit – waiting {RATE_WAIT}s…")
        time.sleep(RATE_WAIT)
        try:
            r = requests.get(UNSPLASH_URL, params=params, headers=headers, timeout=10)
        except:
            return None
        if r.status_code != 200:
            print(f"    ❌  Still {r.status_code} after wait."); return None

    if r.status_code == 401:
        print("    ❌  Invalid API key (401)."); return None
    if r.status_code != 200:
        print(f"    ⚠️  HTTP {r.status_code}"); return None

    results = r.json().get("results", [])
    if not results:
        return None
    urls = results[0].get("urls", {})
    return urls.get("regular") or urls.get("full")

# ── checkpoint helpers ───────────────────────────────────────────────────────
def load_cp():
    if os.path.exists(CHECKPOINT):
        with open(CHECKPOINT, encoding="utf-8") as f:
            return json.load(f)
    return {"fixed": [], "skipped": [], "stats": {"fixed": 0, "skipped": 0, "failed": 0},
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

    # Load all recipes (up to 2000) and filter bad ones client-side
    cur.execute("SELECT id::text, name, cuisine, image_url FROM recipes ORDER BY name")
    all_rows = cur.fetchall()

    bad_rows = [r for r in all_rows if is_bad(r["image_url"])]

    if limit:
        bad_rows = bad_rows[:limit]

    cp = {} if reset else load_cp()
    if reset:
        cp = {"fixed": [], "skipped": [], "stats": {"fixed": 0, "skipped": 0, "failed": 0},
              "started": datetime.now().isoformat()}
    done_ids = set(cp.get("fixed", []) + cp.get("skipped", []))

    print("=" * 65)
    print("  CUISINEE ✦ FIX BAD IMAGES (Unsplash)")
    print("=" * 65)
    print(f"  Total bad/suspicious : {len(bad_rows)}")
    print(f"  Already fixed        : {len(done_ids)}")
    print(f"  Dry run              : {dry_run}")
    print("=" * 65)

    remaining = [r for r in bad_rows if r["id"] not in done_ids]
    print(f"  To process now       : {len(remaining)}")
    print()

    for idx, row in enumerate(remaining, 1):
        rid   = row["id"]
        name  = row["name"]
        q     = smart_query(name)
        print(f"[{idx:>3}/{len(remaining)}] 🔍  {name}")
        print(f"         query: \"{q}\"")

        url = search(q, key)

        if not url:
            # fallback: just the first 3 words + "food"
            fb = " ".join(name.split()[:3]) + " food"
            print(f"         ↩️  fallback: \"{fb}\"")
            url = search(fb, key)

        if url:
            print(f"         ✅  {url[:80]}…")
            if not dry_run:
                cur.execute("UPDATE recipes SET image_url=%s WHERE id=%s::uuid", (url, rid))
                conn.commit()
            cp["fixed"].append(rid)
            cp["stats"]["fixed"] += 1
        else:
            print(f"         ❌  No result – skipping.")
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
    p = argparse.ArgumentParser()
    p.add_argument("--key", default=os.getenv("UNSPLASH_ACCESS_KEY", ""))
    p.add_argument("--limit", type=int, default=0, help="0 = all bad recipes")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--reset", action="store_true", help="Ignore existing checkpoint")
    args = p.parse_args()

    if not args.key:
        print("❌  No Unsplash key. Use --key YOUR_KEY or set UNSPLASH_ACCESS_KEY.")
        sys.exit(1)

    run(args.key, args.limit or None, args.dry_run, args.reset)

if __name__ == "__main__":
    main()
