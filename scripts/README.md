# Scripts Folder

**⚠️ This folder is NOT part of the production application!**

These are utility scripts used for:
- Importing recipe data into the database
- Generating and updating recipe images using AI
- Data analysis and cleanup

## Contents

### Import Scripts
| Script | Purpose |
|--------|---------|
| `import_recipes.py` | Basic recipe import |
| `import_new_recipes.py` | Import with duplicate checking |
| `import_recipes_ai.py` | AI-enhanced import with analysis |
| `seed_recipes.py` | Database seeding |
| `parse_mauritanian_doc.py` | Parse recipes from documents |

### Image Scripts
| Script | Purpose |
|--------|---------|
| `ai_generate_images.py` | Generate images using AI |
| `smart_image_updater.py` | Smart image selection/update |
| `fix_recipe_images.py` | Fix broken image URLs |
| `fix_broken_images.py` | Repair corrupted images |
| `generate_recipe_images.py` | Batch image generation |
| `update_recipe_images.py` | Batch image updates |
| `search_mauritanian_images.py` | Search for recipe images |

### Utility Scripts
| Script | Purpose |
|--------|---------|
| `check_db.py` | Database status check |
| `check_checkpoint.py` | View checkpoint files |
| `check_images.py` | Verify image status |
| `check_image_status.py` | Detailed image report |
| `analyze_recipes.py` | Recipe data analysis |

### Data Files
| File | Purpose |
|------|---------|
| `data/` | Raw recipe JSON files |
| `*.checkpoint.json` | Progress tracking for long operations |

## Do NOT Send This Folder

When sharing the project with teammates, you can exclude this folder. The production code is in:
- `backend/` - The API server
- `frontend/` - The Flutter app

## If You Need to Use These Scripts

1. These scripts require the backend virtual environment
2. Some require API keys (Gemini, Google Custom Search)
3. Copy scripts to `backend/` folder if needed
4. Run with: `python script_name.py`

## Note

The database is already populated with recipes. You shouldn't need these scripts unless you're adding new data sources.
