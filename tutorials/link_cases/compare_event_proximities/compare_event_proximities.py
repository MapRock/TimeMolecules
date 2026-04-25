from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct, Filter, FieldCondition, MatchValue

import hashlib
import json
import math
import pandas as pd
from pathlib import Path

from shared_llm import load_env_upward, read_llm_config, SharedLLM, clean_for_embedding

load_env_upward(__file__)

LLM_CONFIG = read_llm_config()
SHARED_LLM = SharedLLM(LLM_CONFIG)

QDRANT_PATH = LLM_CONFIG.qdrant_path
BASE_COLLECTION_NAME = LLM_CONFIG.collection_name
COLLECTION_NAME = f"{BASE_COLLECTION_NAME}_prop_compare"


def is_nullish(value) -> bool:
    try:
        return pd.isna(value)
    except Exception:
        return value is None


def normalize_value(value) -> str:
    if is_nullish(value):
        return ""
    text = str(value).strip()
    if text.upper() == "NULL":
        return ""
    return text


def canonical_property_value(row: pd.Series) -> str:
    alpha = normalize_value(row.get("PropertyValueAlpha"))
    numeric = normalize_value(row.get("PropertyValueNumeric"))
    return alpha if alpha else numeric


def make_stable_int_id(*parts: str) -> int:
    key = "|".join(normalize_value(p).lower() for p in parts)
    digest = hashlib.sha256(key.encode("utf-8")).digest()
    return int.from_bytes(digest[:8], byteorder="big", signed=False)


def build_unique_key(row: pd.Series) -> str:
    return "|".join([
        normalize_value(row.get("SourceServer")),
        normalize_value(row.get("SourceTableName")),
        normalize_value(row.get("SourceColumn")),
        normalize_value(row.get("PropertyName")),
        canonical_property_value(row),
    ]).lower()


def is_gps_property(row: pd.Series) -> bool:
    property_name = normalize_value(row.get("PropertyName")).lower()
    value = canonical_property_value(row).lower()

    return (
        property_name in {"point", "gps", "location", "coordinate", "coordinates"}
        and "lat" in value
        and "lon" in value
    )


def parse_gps_value(value: str):
    if not value:
        return None

    try:
        parsed = json.loads(value)
        lat = float(parsed["lat"])
        lon = float(parsed["lon"])
        return lat, lon
    except Exception:
        return None


def haversine_meters(lat1, lon1, lat2, lon2) -> float:
    radius_m = 6371000.0

    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(d_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    )

    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return radius_m * c


def gps_similarity_score(distance_meters: float, max_distance_meters: float = 100.0) -> float:
    if distance_meters <= 0:
        return 1.0

    score = 1.0 - (distance_meters / max_distance_meters)
    return max(0.0, min(1.0, score))


def same_property_and_source(left: pd.Series, right_payload: dict) -> bool:
    return (
        normalize_value(left.get("PropertyName")).lower()
        == normalize_value(right_payload.get("PropertyName")).lower()
        and normalize_value(left.get("SourceColumn")).lower()
        == normalize_value(right_payload.get("SourceColumn")).lower()
    )


def build_property_embedding_text(row: pd.Series, value_only: bool = False) -> str:
    property_value = clean_for_embedding(canonical_property_value(row))

    if value_only:
        return "\n".join([
            f"Property Value: {property_value}",
            f"Value: {property_value}",
            f"Comparable Value: {property_value}",
            f"Raw Value: {property_value}",
        ])

    property_name = clean_for_embedding(normalize_value(row.get("PropertyName")))
    source_column = clean_for_embedding(normalize_value(row.get("SourceColumn")))
    source_column_description = clean_for_embedding(normalize_value(row.get("SourceColumnDescription")))
    event = clean_for_embedding(normalize_value(row.get("Event")))
    event_description = clean_for_embedding(normalize_value(row.get("EventDescription")))
    case_type = clean_for_embedding(normalize_value(row.get("CaseType")))

    parts = [
        f"Property Value: {property_value}",
        f"Value: {property_value}",
        f"Comparable Value: {property_value}",
        f"Property Name: {property_name}",
        f"Attribute Name: {property_name}",
    ]

    if source_column:
        parts.append(f"Source Column: {source_column}")
    if source_column_description:
        parts.append(f"Column Meaning: {source_column_description}")
    if event:
        parts.append(f"Event: {event}")
    if event_description:
        parts.append(f"Event Meaning: {event_description}")
    if case_type:
        parts.append(f"Case Type: {case_type}")

    return "\n".join(p for p in parts if p.strip())

def row_to_payload(row: pd.Series) -> dict:
    payload = {}

    for col, value in row.items():
        if not is_nullish(value):
            payload[col] = value.item() if hasattr(value, "item") else value

    payload["PropertyName"] = normalize_value(row.get("PropertyName"))
    payload["SourceColumn"] = normalize_value(row.get("SourceColumn"))
    payload["CanonicalPropertyValue"] = canonical_property_value(row)
    payload["PropCompareKey"] = build_unique_key(row)
    payload["IsGPSProperty"] = is_gps_property(row)

    return payload


def build_points(df: pd.DataFrame) -> list[PointStruct]:
    required = {"CaseSet", "PropertyName", "PropertyValueAlpha", "PropertyValueNumeric"}
    missing = required - set(df.columns)

    if missing:
        raise ValueError(f"Missing required columns: {sorted(missing)}")

    points = []

    for _, row in df.iterrows():
        if is_gps_property(row):
            continue

        property_value = canonical_property_value(row)
        if not property_value:
            continue

        vector_text = build_property_embedding_text(row, value_only=False)
        if not vector_text.strip():
            continue

        point_id = make_stable_int_id(
            normalize_value(row.get("SourceServer")),
            normalize_value(row.get("SourceTableName")),
            normalize_value(row.get("SourceColumn")),
            normalize_value(row.get("PropertyName")),
            property_value,
        )

        vector = SHARED_LLM.embed_text(vector_text)

        points.append(
            PointStruct(
                id=point_id,
                vector=vector,
                payload=row_to_payload(row),
            )
        )

    return points


def ensure_collection(client: QdrantClient, vector_size: int):
    if not client.collection_exists(COLLECTION_NAME):
        client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(
                size=vector_size,
                distance=Distance.COSINE,
            ),
        )


def upsert_csv(csv_path: str) -> pd.DataFrame:
    df = pd.read_csv(csv_path, sep=None, engine="python")
    points = build_points(df)

    if not points:
        raise ValueError("No non-GPS embeddable property rows found.")

    client = QdrantClient(path=QDRANT_PATH)

    try:
        ensure_collection(client, len(points[0].vector))
        client.upsert(collection_name=COLLECTION_NAME, points=points)
    finally:
        client.close()

    return df


def make_result_row(
    left,
    right_payload,
    score,
    match_method,
    distance_meters=None,
):
    row = {
        "left_CaseSet": left.get("CaseSet"),
        "left_CaseID": left.get("CaseID"),
        "left_EventID": left.get("EventID"),
        "left_Event": left.get("Event"),
        "left_EventDescription": left.get("EventDescription"),
        "left_PropertyName": left.get("PropertyName"),
        "left_PropertyValue": canonical_property_value(left),
        "left_SourceColumn": left.get("SourceColumn"),

        "right_CaseSet": right_payload.get("CaseSet"),
        "right_CaseID": right_payload.get("CaseID"),
        "right_EventID": right_payload.get("EventID"),
        "right_Event": right_payload.get("Event"),
        "right_EventDescription": right_payload.get("EventDescription"),
        "right_PropertyName": right_payload.get("PropertyName"),
        "right_PropertyValue": right_payload.get("CanonicalPropertyValue"),
        "right_SourceColumn": right_payload.get("SourceColumn"),

        "SimilarityScore": round(float(score), 4),
        "MatchMethod": match_method,
    }

    if distance_meters is not None:
        row["DistanceMeters"] = round(float(distance_meters), 3)

    return row


def compare_gps_rows(
    df: pd.DataFrame,
    left_caseset=1,
    right_caseset=2,
    max_distance_meters=100.0,
    min_score=0.70,
) -> list[dict]:

    gps_df = df[df.apply(is_gps_property, axis=1)].copy()

    left_df = gps_df[gps_df["CaseSet"].astype(str) == str(left_caseset)].copy()
    right_df = gps_df[gps_df["CaseSet"].astype(str) == str(right_caseset)].copy()

    rows = []

    for _, left in left_df.iterrows():
        left_point = parse_gps_value(canonical_property_value(left))
        if not left_point:
            continue

        for _, right in right_df.iterrows():
            right_point = parse_gps_value(canonical_property_value(right))
            if not right_point:
                continue

            distance = haversine_meters(
                left_point[0],
                left_point[1],
                right_point[0],
                right_point[1],
            )

            score = gps_similarity_score(distance, max_distance_meters=max_distance_meters)

            if score < min_score:
                continue

            right_payload = row_to_payload(right)

            rows.append(
                make_result_row(
                    left=left,
                    right_payload=right_payload,
                    score=score,
                    match_method="gps_haversine",
                    distance_meters=distance,
                )
            )

    return rows


def compare_embedding_rows(
    df: pd.DataFrame,
    left_caseset=1,
    right_caseset=2,
    top_k=5,
    min_score=0.70,
) -> list[dict]:

    non_gps_df = df[~df.apply(is_gps_property, axis=1)].copy()
    left_df = non_gps_df[non_gps_df["CaseSet"].astype(str) == str(left_caseset)].copy()

    right_filter = Filter(
        must=[
            FieldCondition(
                key="CaseSet",
                match=MatchValue(value=right_caseset),
            ),
            FieldCondition(
                key="IsGPSProperty",
                match=MatchValue(value=False),
            ),
        ]
    )

    rows = []
    client = QdrantClient(path=QDRANT_PATH)

    try:

       for _, left in left_df.iterrows():
        left_value = canonical_property_value(left)
        if not left_value:
            continue

        # First try a narrow search: same CaseSet + same PropertyName + same SourceColumn.
        same_name_source_filter = Filter(
            must=[
                FieldCondition(
                    key="PropertyName",
                    match=MatchValue(value=normalize_value(left.get("PropertyName"))),
                ),
                FieldCondition(
                    key="SourceColumn",
                    match=MatchValue(value=normalize_value(left.get("SourceColumn"))),
                )

            ]
        )

        query_text = build_property_embedding_text(left, value_only=True)
        query_vector = SHARED_LLM.embed_text(query_text)

        hits = client.query_points(
            collection_name=COLLECTION_NAME,
            query=query_vector,
            query_filter=same_name_source_filter,
            limit=top_k,
            with_payload=True,
        ).points

        match_method = "embedding_value_only_same_property_source"

        # Fallback: if no same-property/source candidates exist, use broader contextual comparison.
        if not hits:
            query_text = build_property_embedding_text(left, value_only=False)
            query_vector = SHARED_LLM.embed_text(query_text)

            hits = client.query_points(
                collection_name=COLLECTION_NAME,
                query=query_vector,
                query_filter=right_filter,
                limit=top_k,
                with_payload=True,
            ).points

            match_method = "embedding_contextual"

        for hit in hits:
            if hit.score < min_score:
                continue

            rows.append(
                make_result_row(
                    left=left,
                    right_payload=hit.payload or {},
                    score=hit.score,
                    match_method=match_method,
                )
            ) 


    finally:
        client.close()

    return rows


def compare_case_sets(
    df: pd.DataFrame,
    left_caseset=1,
    right_caseset=2,
    top_k=5,
    min_score=0.70,
    gps_max_distance_meters=100.0,
) -> pd.DataFrame:

    embedding_rows = compare_embedding_rows(
        df=df,
        left_caseset=left_caseset,
        right_caseset=right_caseset,
        top_k=top_k,
        min_score=min_score,
    )

    gps_rows = compare_gps_rows(
        df=df,
        left_caseset=left_caseset,
        right_caseset=right_caseset,
        max_distance_meters=gps_max_distance_meters,
        min_score=min_score,
    )

    results = pd.DataFrame(embedding_rows + gps_rows)

    if results.empty:
        return results

    results = results.sort_values(
        by=["MatchMethod", "SimilarityScore"],
        ascending=[True, False],
    )

    return results


if __name__ == "__main__":
    csv_path = r"C:\MapRock\TimeMolecules\tutorials\link_cases\compare_event_proximities\compare_event_proximities.csv"

    print(f"✅ Beginning creation of Qdrant collection and embedding properties from CSV.")
    df = upsert_csv(csv_path)

    print(f"✅ Beginning comparison of event proximities between CaseSet {1} and CaseSet {2}...")
    results = compare_case_sets(
        df,
        left_caseset=1,
        right_caseset=2,
        top_k=5,
        min_score=0.70,
        gps_max_distance_meters=100.0,
    )

    out_path = Path(csv_path).with_name("compare_event_proximities_results.csv")
    results.to_csv(out_path, index=False, encoding="utf-8")

    print(f"✅ Comparison of event proximities between CaseSet {1} and CaseSet {2} completed.")
    print(f"✅ Results written to: {out_path}")