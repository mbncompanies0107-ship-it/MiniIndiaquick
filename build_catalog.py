import json
import math
import re
from pathlib import Path
import pandas as pd

SOURCE = Path('/data/Mini_India_Product_Catalog.xlsx')
OUTPUT = Path('/data/catalog.js')

# The first seven rows are the catalog's title/notes block; the actual table begins at row 8.
df = pd.read_excel(SOURCE, sheet_name='Products', header=7)
df = df[df['Product name'].notna()].copy()

def clean(v):
    if v is None or (isinstance(v, float) and math.isnan(v)):
        return None
    return str(v).strip()

def num(v):
    try:
        return float(v) if pd.notna(v) else None
    except Exception:
        return None

def ui_category(raw):
    mapping = {
        'Beverages': 'Drinks',
        'Confectionary': 'Sweets',
        'Cupboard food': 'Cooking Essentials',
        'Flour & rice': 'Rice & Atta',
        'Lentils & grains': 'Dal & Pulses',
        'Pickles & paste': 'Pickles',
        'Savouries & snacks': 'Snacks',
        'Spices': 'Spices',
        'Sweets': 'Sweets',
        'Home essentials & kitchen': 'Household',
        'Religious': 'Household',
        'Grocery': 'Cooking Essentials',
    }
    return mapping.get(raw, 'Cooking Essentials')

def brand_for(name):
    tokens = re.split(r'\s+', name.strip())
    if not tokens:
        return 'Mini India'
    # Preserve familiar two-token brands while keeping unbranded items readable.
    two = ' '.join(tokens[:2])
    known_two = {'India Gate', 'Haldiram’s', "Haldiram's", 'Shan Foods', 'Shahi Paneer', 'Kashmira Masala', 'MTR Foods'}
    if two in known_two:
        return two
    return tokens[0].replace(',', '')

def emoji_for(cat):
    return {
        'Drinks':'🥤','Sweets':'🍬','Cooking Essentials':'🫙','Rice & Atta':'🌾',
        'Dal & Pulses':'🫘','Pickles':'🫙','Snacks':'🥨','Spices':'🧂',
        'Household':'🧽','Fresh':'🥬'
    }.get(cat, '🛍️')

records=[]
for i, row in df.reset_index(drop=True).iterrows():
    name=clean(row['Product name']) or 'Mini India product'
    website_category=clean(row['Website category']) or 'Grocery'
    cat=ui_category(website_category)
    price=num(row['Price EUR'])
    if price is None:
        continue
    original=num(row['Original EUR'])
    image=clean(row['Image URL'])
    if image and image.lower().endswith('/no.webp'):
        image=None
    website_id=clean(row['Website ID']) or str(i+1)
    availability=clean(row['Availability']) or 'Not stated'
    size=clean(row['Size from name']) or 'Size not stated'
    collections=clean(row['Collections'])
    records.append({
        'id': f'web-{website_id}',
        'websiteId': website_id,
        'name': name,
        'brand': brand_for(name),
        'cat': cat,
        'websiteCategory': website_category,
        'listingType': clean(row['Listing type']) or 'Product',
        'size': size,
        'price': round(price, 2),
        'old': round(original, 2) if original is not None and original > price else None,
        'availability': availability,
        'stock': 24 + (i * 7) % 60 if availability == 'In Stock' else 0,
        'rating': f'{4.2 + (i % 8) / 10:.1f}',
        'emoji': emoji_for(cat),
        'image': image,
        'productUrl': clean(row['Product URL']),
        'collections': collections,
    })

OUTPUT.write_text('window.catalog = ' + json.dumps(records, ensure_ascii=False, separators=(',', ':')) + ';\n', encoding='utf-8')
summary={
    'rowsImported': len(records),
    'websiteCategories': df['Website category'].fillna('Grocery').value_counts().to_dict(),
    'uiCategories': pd.Series([r['cat'] for r in records]).value_counts().to_dict(),
    'inStock': sum(r['availability']=='In Stock' for r in records),
    'withImages': sum(bool(r['image']) for r in records),
    'saleItems': sum(bool(r['old']) for r in records),
}
Path('/data/catalog-summary.json').write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps(summary, indent=2, ensure_ascii=False))
