"""Check current image status in the database."""
import psycopg2
from app.config import get_settings
settings = get_settings()

FALLBACK_PATTERNS = [
    "unsplash.com/photo-1504674900247",
    "unsplash.com/photo-1540189549336",
    "unsplash.com/photo-1565299624946",
    "unsplash.com/photo-1567620905732",
]

def main():
    conn = psycopg2.connect(settings.database_url)
    cur = conn.cursor()
    
    # Total recipes
    cur.execute("SELECT COUNT(*) FROM recipes")
    total = cur.fetchone()[0]
    print(f"Total recipes: {total}")
    
    # Recipes with fallback images
    conditions = " OR ".join([f"image_url LIKE '%{p}%'" for p in FALLBACK_PATTERNS])
    cur.execute(f"SELECT COUNT(*) FROM recipes WHERE {conditions}")
    fallback_count = cur.fetchone()[0]
    print(f"Recipes with fallback/generic images: {fallback_count}")
    
    # Recipes with NULL or empty images
    cur.execute("SELECT COUNT(*) FROM recipes WHERE image_url IS NULL OR image_url = ''")
    null_count = cur.fetchone()[0]
    print(f"Recipes with NULL/empty images: {null_count}")
    
    # Recipes with good images
    good_count = total - fallback_count - null_count
    print(f"Recipes with unique images: {good_count}")
    
    print(f"\n📊 Summary:")
    print(f"   ✅ Good images: {good_count}")
    print(f"   ⚠️  Need update: {fallback_count + null_count}")
    
    conn.close()

if __name__ == "__main__":
    main()
