import pandas as pd
import json
from io import StringIO
import requests
from typing import List, Dict, Any

def safe_json_loads(text):
    """Safely parse JSON, handling nulls, empty strings, etc."""
    if pd.isna(text) or not str(text).strip() or str(text).strip() in ['[]', 'null', 'None', '']:
        return []
    try:
        return json.loads(str(text))
    except Exception:
        return []

# ====================== SOURCE ======================
# You can change this to a local path if you already downloaded the CSV
SOURCE = "https://raw.githubusercontent.com/MapRock/TimeMolecules/main/data/timesolution_schema/TimeMolecules_Metadata.csv"
# SOURCE = "TimeMolecules_Metadata.csv"   # ← use this if you have the file locally

print("Loading TimeMolecules_Metadata.csv...")
if SOURCE.startswith("http"):
    response = requests.get(SOURCE)
    response.raise_for_status()
    df = pd.read_csv(StringIO(response.text))
else:
    df = pd.read_csv(SOURCE)

# Filter ONLY the programmable objects (procs, TVFs, UDFs) that have ParametersJson
df_programmable = df[
    (df['ParametersJson'].notna()) & 
    (df['ParametersJson'].astype(str).str.strip() != '') &
    (df['ParametersJson'].astype(str).str.strip() != '[]')
].copy().reset_index(drop=True)

print(f"Found {len(df_programmable)} programmable objects (Stored Procs / TVFs / UDFs)")

# ====================== 1. OBJECTS CSV ======================
# One row per object (normalized entity table)
objects_df = df_programmable[[
    'ObjectType',
    'ObjectName',
    'Description',
    'Utilization',
    'SampleCode'          # included in case you want the example code
]].copy()

objects_df = objects_df.rename(columns={
    'ObjectType': 'object_type',
    'ObjectName': 'object_name',
    'Description': 'object_description',
    'Utilization': 'utilization',
    'SampleCode': 'sample_code'
})

# Add a clean primary key column (object_name is unique)
objects_df = objects_df.sort_values('object_name').reset_index(drop=True)

# ====================== 2. DETAILS CSV (parameters/outputs/references) ======================
flattened: List[Dict] = []

for _, row in df_programmable.iterrows():
    obj_name = str(row.get('ObjectName', '')).strip()

    # === INPUTS (from ParametersJson) ===
    params = safe_json_loads(row['ParametersJson'])
    for p in params:
        flattened.append({
            'object_name': obj_name,
            'category': 'Input',
            'item_name': p.get('name', p.get('Name', '')),
            'item_type': p.get('type', p.get('Type', '')),
            'item_description': p.get('description', p.get('Description', '')),
            'default_value': p.get('default', p.get('Default', ''))
        })

    # === OUTPUTS (from OutputNotes) ===
    outputs = safe_json_loads(row.get('OutputNotes'))
    for o in outputs:
        flattened.append({
            'object_name': obj_name,
            'category': 'Output',
            'item_name': o.get('name', o.get('Name', 'ResultSet')),
            'item_type': o.get('type', o.get('Type', '')),
            'item_description': o.get('description', o.get('Description', '')),
            'default_value': ''
        })

    # === REFERENCES (from ReferencedObjectsJson) ===
    refs = safe_json_loads(row.get('ReferencedObjectsJson'))
    for r in refs:
        flattened.append({
            'object_name': obj_name,
            'category': 'Reference',
            'item_name': r.get('name', r.get('Name', '')),
            'item_type': r.get('type', r.get('Type', '')),
            'item_description': r.get('description', r.get('Description', '')),
            'default_value': ''
        })

details_df = pd.DataFrame(flattened)
details_df = details_df.sort_values(by=['object_name', 'category', 'item_name']).reset_index(drop=True)

# ====================== SAVE TWO NORMALIZED CSVs ======================
objects_file = r'C:\MapRock\TimeMolecules\data\TimeMolecules_Objects.csv'
details_file = r'C:\MapRock\TimeMolecules\data\TimeMolecules_Object_Items.csv'

objects_df.to_csv(objects_file, index=False)
details_df.to_csv(details_file, index=False)

print(f"\n✅ Success! Created TWO normalized CSVs:")
print(f"   • {objects_file}  ({len(objects_df)} objects)")
print(f"   • {details_file}  ({len(details_df)} items)")
print("\nBreakdown by category in details file:")
print(details_df['category'].value_counts())
print("\nObjects preview:")
print(objects_df.head())
print("\nDetails preview (first 15 rows):")
print(details_df.head(15)[['object_name', 'category', 'item_name', 'item_type', 'item_description']])