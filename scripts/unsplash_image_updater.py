"""
CUISINEE UNSPLASH IMAGE UPDATER
================================
Reads recipe names from the database and fetches professional food
photos from the Unsplash API, then saves the best matching image URL
back to each recipe's `image_url` field.

Only processes the first N recipes (default: 50).

Prerequisites
-------------
1. Install requests and python-dotenv:
       pip install requests python-dotenv psycopg2-binary

2. Get a FREE Unsplash API key:
       https://unsplash.com/developers  →  New Application
       Copy the "Access Key".

3. Either:
   a) Pass the key on the command line:
          python unsplash_image_updater.py --key YOUR_ACCESS_KEY
   b) Set it as an environment variable:
          UNSPLASH_ACCESS_KEY=YOUR_ACCESS_KEY
   c) Add it to backend/.env:
          UNSPLASH_ACCESS_KEY=YOUR_ACCESS_KEY

Usage (run from the backend/ directory)
-----------------------------------------
    python ../scripts/unsplash_image_updater.py --key YOUR_KEY
    python ../scripts/unsplash_image_updater.py --key YOUR_KEY --limit 50
    python ../scripts/unsplash_image_updater.py --key YOUR_KEY --dry-run
    python ../scripts/unsplash_image_updater.py --key YOUR_KEY --reset
"""

import os
import sys
import json
import time
import argparse
import requests
from datetime import datetime
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Load .env from backend/ directory (whether we run from there or from scripts/)
# ---------------------------------------------------------------------------
_this_dir = os.path.dirname(os.path.abspath(__file__))
_backend_dir = os.path.join(os.path.dirname(_this_dir), "backend")
_env_path = os.path.join(_backend_dir, ".env")

try:
    from dotenv import load_dotenv
    if os.path.exists(_env_path):
        load_dotenv(_env_path)
except ImportError:
    # dotenv not installed – rely on real environment variables
    pass

# ---------------------------------------------------------------------------
# Database – use psycopg2 directly so this script is fully standalone
# ---------------------------------------------------------------------------
try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    print("❌  psycopg2 is not installed.")
    print("    Run:  pip install psycopg2-binary")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
UNSPLASH_SEARCH_URL = "https://api.unsplash.com/search/photos"
CHECKPOINT_FILE = os.path.join(_this_dir, "unsplash_checkpoint.json")
API_DELAY = 75           # Unsplash free tier: 50 req/hour → ≥72 s between calls
RATE_LIMIT_WAIT = 120   # Extra wait (seconds) when a 403 is received
DEFAULT_LIMIT = 50
IMAGE_SIZE = "regular"   # "small" (400px) | "regular" (1080px) | "full" | "raw"


# ---------------------------------------------------------------------------
# Checkpoint helpers
# ---------------------------------------------------------------------------
def load_checkpoint() -> dict:
    if os.path.exists(CHECKPOINT_FILE):
        with open(CHECKPOINT_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {
        "updated_ids": [],
        "failed_ids": [],
        "stats": {"updated": 0, "failed": 0, "skipped": 0},
        "started_at": datetime.now().isoformat(),
    }


def save_checkpoint(cp: dict):
    cp["last_updated"] = datetime.now().isoformat()
    with open(CHECKPOINT_FILE, "w", encoding="utf-8") as f:
        json.dump(cp, f, indent=2, ensure_ascii=False)


# ---------------------------------------------------------------------------
# Unsplash search
# ---------------------------------------------------------------------------
def search_unsplash(query: str, access_key: str) -> Optional[str]:
    """
    Search Unsplash for a food image matching *query*.
    Returns the ``regular`` URL (≈1080 px wide) of the best result, or None.
    """
    params = {
        "query": query,
        "per_page": 5,
        "orientation": "landscape",
        "content_filter": "high",   # only high-quality / safe photos
    }
    headers = {
        "Authorization": f"Client-ID {access_key}",
        "Accept-Version": "v1",
    }

    try:
        resp = requests.get(
            UNSPLASH_SEARCH_URL,
            params=params,
            headers=headers,
            timeout=10,
        )
    except requests.exceptions.RequestException as exc:
        print(f"    ⚠️  Network error: {exc}")
        return None

    if resp.status_code == 401:
        print("    ❌  Unsplash: invalid access key (401).")
        return None
    if resp.status_code == 403:
        print(f"    ⏳  Unsplash rate-limit (403) – waiting {RATE_LIMIT_WAIT}s then retrying…")
        time.sleep(RATE_LIMIT_WAIT)
        # One automatic retry after the cool-down
        try:
            resp = requests.get(
                UNSPLASH_SEARCH_URL, params=params, headers=headers, timeout=10
            )
        except requests.exceptions.RequestException:
            return None
        if resp.status_code != 200:
            print(f"    ❌  Still failing after wait (HTTP {resp.status_code}).")
            return None
    if resp.status_code != 200:
        print(f"    ⚠️  Unsplash HTTP {resp.status_code}")
        return None

    data = resp.json()
    results = data.get("results", [])
    if not results:
        return None

    # Pick the first result – Unsplash already ranks by relevance
    photo = results[0]
    urls = photo.get("urls", {})
    return urls.get(IMAGE_SIZE) or urls.get("regular") or urls.get("full")


# ---------------------------------------------------------------------------
# Main updater
# ---------------------------------------------------------------------------
def run(access_key: str, limit: int, dry_run: bool, reset: bool, skip_existing: bool):
    database_url = os.getenv("DATABASE_URL", "")
    if not database_url:
        print("❌  DATABASE_URL is not set.")
        print(f"    Add it to {_env_path} or export it as an environment variable.")
        sys.exit(1)

    # psycopg2 expects "postgresql://" not "postgres://"
    database_url = database_url.replace("postgres://", "postgresql://", 1)

    # Connect
    try:
        conn = psycopg2.connect(database_url)
        conn.autocommit = False
    except Exception as exc:
        print(f"❌  Cannot connect to database: {exc}")
        sys.exit(1)

    cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

    # Load / reset checkpoint
    cp = {} if reset else load_checkpoint()
    if reset:
        cp = {
            "updated_ids": [],
            "failed_ids": [],
            "stats": {"updated": 0, "failed": 0, "skipped": 0},
            "started_at": datetime.now().isoformat(),
        }

    already_done = set(cp.get("updated_ids", []))

    # Fetch first N recipes
    cur.execute(
        "SELECT id::text, name, cuisine, image_url FROM recipes ORDER BY created_at LIMIT %s",
        (limit,),
    )
    recipes = cur.fetchall()

    print("=" * 65)
    print("  CUISINEE ✦ UNSPLASH IMAGE UPDATER")
    print("=" * 65)
    print(f"  Recipes to process : {len(recipes)}")
    print(f"  Already completed  : {len(already_done)}")
    print(f"  Image size         : {IMAGE_SIZE} (~1080 px wide)")
    print(f"  Dry run            : {dry_run}")
    print(f"  Skip if has image  : {skip_existing}")
    print("=" * 65)
    print()

    for idx, row in enumerate(recipes, start=1):
        recipe_id = row["id"]
        name = row["name"]
        cuisine = row["cuisine"] or ""
        current_image = row["image_url"] or ""

        prefix = f"[{idx:>3}/{len(recipes)}]"

        # Skip already processed
        if recipe_id in already_done:
            print(f"{prefix} ⏭️  Skipping (already done): {name}")
            cp["stats"]["skipped"] += 1
            continue

        # Optionally skip recipes that already have a good image
        if skip_existing and current_image and current_image.startswith("http"):
            print(f"{prefix} ⏭️  Skipping (has image): {name}")
            cp["stats"]["skipped"] += 1
            continue

        # Build search query – be specific so Unsplash returns food shots
        query = f"{name} {cuisine} food dish recipe".strip()
        print(f"{prefix} 🔍  {name}  →  query: \"{query}\"")

        image_url = search_unsplash(query, access_key)

        if not image_url:
            # Try a simpler fallback query
            fallback = f"{name} food"
            print(f"         ↩️  Retrying with fallback: \"{fallback}\"")
            image_url = search_unsplash(fallback, access_key)

        if not image_url:
            print(f"         ❌  No image found – skipping.")
            cp["failed_ids"].append(recipe_id)
            cp["stats"]["failed"] += 1
        else:
            print(f"         ✅  {image_url[:80]}...")
            if not dry_run:
                cur.execute(
                    "UPDATE recipes SET image_url = %s WHERE id = %s::uuid",
                    (image_url, recipe_id),
                )
                conn.commit()
            cp["updated_ids"].append(recipe_id)
            cp["stats"]["updated"] += 1

        save_checkpoint(cp)
        time.sleep(API_DELAY)

    cur.close()
    conn.close()

    print()
    print("=" * 65)
    print("  DONE")
    print(f"  ✅  Updated : {cp['stats']['updated']}")
    print(f"  ❌  Failed  : {cp['stats']['failed']}")
    print(f"  ⏭️  Skipped : {cp['stats']['skipped']}")
    if dry_run:
        print()
        print("  ⚠️  DRY-RUN: no changes were committed to the database.")
    print("=" * 65)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Update recipe images using the Unsplash API."
    )
    parser.add_argument(
        "--key",
        default=os.getenv("UNSPLASH_ACCESS_KEY", ""),
        help="Unsplash Access Key (or set UNSPLASH_ACCESS_KEY env var)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=DEFAULT_LIMIT,
        help=f"Number of recipes to process (default: {DEFAULT_LIMIT})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Search but do NOT update the database",
    )
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Ignore existing checkpoint and start fresh",
    )
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="Skip recipes that already have an image_url",
    )

    args = parser.parse_args()

    if not args.key:
        print("❌  No Unsplash access key provided.")
        print()
        print("  Option 1 – pass it on the command line:")
        print("        python unsplash_image_updater.py --key YOUR_KEY")
        print()
        print("  Option 2 – set an environment variable:")
        print("        set UNSPLASH_ACCESS_KEY=YOUR_KEY   (Windows)")
        print("        export UNSPLASH_ACCESS_KEY=YOUR_KEY (macOS/Linux)")
        print()
        print("  Option 3 – add to backend/.env:")
        print("        UNSPLASH_ACCESS_KEY=YOUR_KEY")
        print()
        print("  Get a free key at: https://unsplash.com/developers")
        sys.exit(1)

    run(
        access_key=args.key,
        limit=args.limit,
        dry_run=args.dry_run,
        reset=args.reset,
        skip_existing=args.skip_existing,
    )


if __name__ == "__main__":
    main()
