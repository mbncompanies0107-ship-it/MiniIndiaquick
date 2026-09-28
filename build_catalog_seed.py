import math
from pathlib import Path
import pandas as pd

src=Path('/data/Mini_India_Product_Catalog.xlsx')
out=Path('/data/catalog-seed.sql')
df=pd.read_excel(src, sheet_name='Products', header=7)
df=df[df['Product name'].notna()].copy()
map_cat={'Beverages':'Drinks','Confectionary':'Sweets','Cupboard food':'Cooking Essentials','Flour & rice':'Rice & Atta','Lentils & grains':'Dal & Pulses','Pickles & paste':'Pickles','Savouries & snacks':'Snacks','Spices':'Spices','Sweets':'Sweets','Home essentials & kitchen':'Household','Religious':'Household','Grocery':'Cooking Essentials'}
def clean(v):
    return None if v is None or (isinstance(v,float) and math.isnan(v)) else str(v).strip()
def sql(v):
    if v is None: return 'NULL'
    return "'"+str(v).replace("'","''")+"'"
def num(v):
    try: return float(v) if pd.notna(v) else None
    except: return None
lines=['-- Generated from Mini_India_Product_Catalog.xlsx; run after schema.sql.','BEGIN;','']
for c in sorted(set(map_cat.values())):
    lines.append(f"INSERT INTO categories (name) VALUES ({sql(c)}) ON CONFLICT (name) DO NOTHING;")
lines.append('')
for _,r in df.iterrows():
    name=clean(r['Product name'])
    price=num(r['Price EUR'])
    if not name or price is None: continue
    website_id=clean(r['Website ID']) or name
    cat=map_cat.get(clean(r['Website category']),'Cooking Essentials')
    original=num(r['Original EUR'])
    if original is not None and original <= price: original=None
    img=clean(r['Image URL'])
    if img and img.lower().endswith('/no.webp'): img=None
    size=clean(r['Size from name']) or 'Size not stated'
    sku='MI-WEB-'+website_id
    desc=f"{name} — imported from the Mini India Ireland public catalog."
    lines.append("INSERT INTO products (category_id,name,brand,size,sku,price_eur,compare_at_eur,image_url,description,origin,rating) "
                 f"SELECT id,{sql(name)},{sql(name.split()[0] if name.split() else 'Mini India')},{sql(size)},{sql(sku)},{price:.2f},{'NULL' if original is None else f'{original:.2f}'},{sql(img)},{sql(desc)},'Packed for the Irish market',4.5 "
                 f"FROM categories WHERE name={sql(cat)} ON CONFLICT (sku) DO UPDATE SET name=EXCLUDED.name,price_eur=EXCLUDED.price_eur,compare_at_eur=EXCLUDED.compare_at_eur,image_url=EXCLUDED.image_url,updated_at=now();")
lines += ['', 'COMMIT;', '']
out.write_text('\n'.join(lines),encoding='utf-8')
print(f'Wrote {sum(1 for x in lines if x.startswith("INSERT INTO products"))} product upserts to {out}')
