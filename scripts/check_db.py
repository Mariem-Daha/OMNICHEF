"""Check database tables and their status."""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import inspect
from app.database import engine

def check_tables():
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    
    print("=" * 50)
    print("DATABASE TABLES STATUS")
    print("=" * 50)
    
    required_tables = [
        "recipes",
        "recipe_steps", 
        "nutrition_info",
        "profiles",
        "saved_recipes"
    ]
    
    print(f"\n📋 Tables found in database: {len(tables)}")
    for table in tables:
        print(f"   ✓ {table}")
    
    print(f"\n🔍 Required tables check:")
    all_present = True
    for table in required_tables:
        if table in tables:
            print(f"   ✅ {table} - EXISTS")
        else:
            print(f"   ❌ {table} - MISSING")
            all_present = False
    
    if all_present:
        print("\n✅ All required tables are present!")
    else:
        print("\n⚠️ Some tables are missing. Run the schema.sql in Supabase SQL Editor.")
    
    # Show row counts
    print("\n📊 Row counts:")
    from sqlalchemy import text
    with engine.connect() as conn:
        for table in tables:
            if table in required_tables:
                try:
                    result = conn.execute(text(f"SELECT COUNT(*) FROM {table}"))
                    count = result.scalar()
                    print(f"   {table}: {count} rows")
                except Exception as e:
                    print(f"   {table}: Error - {e}")

if __name__ == "__main__":
    check_tables()
