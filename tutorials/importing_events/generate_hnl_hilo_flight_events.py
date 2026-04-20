import csv
import json
import math
import random
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional


# ============================================================
# CONFIGURATION
# ============================================================

OUTPUT_FILE = Path("C:\\MapRock\\TimeMolecules\\stage_importevents_hnl_ito_roundtrip.csv")
NUM_CASES = 100

SOURCE_ID = 62
CASE_TYPE = "Interisland Round Trip Flight"
NATURALKEY_SOURCECOLUMN_ID = 1001
ACCESS_BITMAP = 0

START_DATE = datetime(2025, 1, 1, 5, 0, 0)
END_DATE = datetime(2025, 3, 31, 22, 0, 0)

RANDOM_SEED = 42
random.seed(RANDOM_SEED)


# ============================================================
# EVENT DEFINITIONS
# ============================================================

EVENT_DEFINITIONS: Dict[str, str] = {
    "book_trip": "Book round-trip interisland flight from Honolulu to Hilo",
    "check_in_outbound": "Check in for outbound flight at Honolulu",
    "bag_drop_outbound": "Drop checked bag for outbound flight at Honolulu",
    "security_outbound": "Clear security screening for outbound flight at Honolulu",
    "gate_wait_outbound": "Wait at gate for outbound flight at Honolulu",
    "outbound_delay": "Outbound flight departure delayed at Honolulu",
    "outbound_cancel": "Outbound flight canceled at Honolulu",
    "rebook_outbound": "Rebook canceled outbound flight from Honolulu to Hilo",
    "board_outbound": "Board outbound flight from Honolulu to Hilo",
    "depart_hnl": "Depart Honolulu on outbound flight to Hilo",
    "go_around_ito": "Go-around during attempted landing in Hilo",
    "arrive_ito": "Arrive in Hilo on outbound flight from Honolulu",
    "change_planes_outbound": "Change planes during outbound itinerary",
    "board_outbound_connection": "Board connecting outbound flight to Hilo",
    "depart_outbound_connection": "Depart on connecting outbound flight to Hilo",
    "arrive_ito_connection": "Arrive in Hilo on connecting outbound flight",
    "baggage_claim_outbound": "Claim checked bag in Hilo after outbound flight",
    "exit_airport_outbound": "Exit Hilo airport after outbound arrival",
    "stay_in_hilo": "Stay in Hilo before return flight",
    "check_in_return": "Check in for return flight at Hilo",
    "bag_drop_return": "Drop checked bag for return flight at Hilo",
    "security_return": "Clear security screening for return flight at Hilo",
    "gate_wait_return": "Wait at gate for return flight at Hilo",
    "return_delay": "Return flight departure delayed at Hilo",
    "return_cancel": "Return flight canceled at Hilo",
    "rebook_return": "Rebook canceled return flight from Hilo to Honolulu",
    "board_return": "Board return flight from Hilo to Honolulu",
    "depart_ito": "Depart Hilo on return flight to Honolulu",
    "go_around_hnl": "Go-around during attempted landing in Honolulu",
    "arrive_hnl": "Arrive in Honolulu on return flight from Hilo",
    "change_planes_return": "Change planes during return itinerary",
    "board_return_connection": "Board connecting return flight to Honolulu",
    "depart_return_connection": "Depart on connecting return flight to Honolulu",
    "arrive_hnl_connection": "Arrive in Honolulu on connecting return flight",
    "baggage_claim_return": "Claim checked bag in Honolulu after return flight",
    "exit_airport_return": "Exit Honolulu airport after return arrival",
    "trip_complete": "Round-trip interisland flight case complete",
}


# ============================================================
# TRANSITIONS
# Each transition includes:
# - next_event
# - probability weight
# - timing distribution type
# - timing parameters
#
# Supported distributions:
# - uniform: a, b
# - triangular: low, mode, high
# - normal: mean, std, low, high
# - lognormal: mean, sigma, low, high
# ============================================================

@dataclass
class Transition:
    next_event: str
    weight: float
    dist: str
    params: dict


TRANSITIONS: Dict[str, List[Transition]] = {
    "book_trip": [
        Transition("check_in_outbound", 1.0, "uniform", {"a": 60, "b": 60 * 24 * 40}),
    ],

    "check_in_outbound": [
        Transition("bag_drop_outbound", 0.58, "triangular", {"low": 4, "mode": 8, "high": 18}),
        Transition("security_outbound", 0.42, "triangular", {"low": 5, "mode": 10, "high": 20}),
    ],
    "bag_drop_outbound": [
        Transition("security_outbound", 1.0, "triangular", {"low": 5, "mode": 9, "high": 18}),
    ],
    "security_outbound": [
        Transition("gate_wait_outbound", 1.0, "normal", {"mean": 18, "std": 7, "low": 6, "high": 40}),
    ],
    "gate_wait_outbound": [
        Transition("outbound_cancel", 0.015, "uniform", {"a": 20, "b": 90}),
        Transition("outbound_delay", 0.16, "triangular", {"low": 12, "mode": 28, "high": 75}),
        Transition("board_outbound", 0.825, "triangular", {"low": 12, "mode": 30, "high": 50}),
    ],
    "outbound_delay": [
        Transition("outbound_cancel", 0.03, "uniform", {"a": 20, "b": 90}),
        Transition("board_outbound", 0.97, "lognormal", {"mean": 3.35, "sigma": 0.38, "low": 12, "high": 120}),
    ],
    "outbound_cancel": [
        Transition("rebook_outbound", 1.0, "lognormal", {"mean": 5.2, "sigma": 0.45, "low": 60, "high": 720}),
    ],
    "rebook_outbound": [
        Transition("check_in_outbound", 1.0, "uniform", {"a": 180, "b": 60 * 24 * 2}),
    ],
    "board_outbound": [
        Transition("depart_hnl", 1.0, "triangular", {"low": 8, "mode": 16, "high": 28}),
    ],
    "depart_hnl": [
        Transition("change_planes_outbound", 0.03, "uniform", {"a": 30, "b": 55}),
        Transition("go_around_ito", 0.002, "uniform", {"a": 35, "b": 50}),  # about 1 in 500
        Transition("arrive_ito", 0.968, "normal", {"mean": 44, "std": 5, "low": 34, "high": 60}),
    ],
    "go_around_ito": [
        Transition("arrive_ito", 1.0, "triangular", {"low": 12, "mode": 18, "high": 28}),
    ],
    "change_planes_outbound": [
        Transition("board_outbound_connection", 1.0, "lognormal", {"mean": 3.8, "sigma": 0.35, "low": 25, "high": 120}),
    ],
    "board_outbound_connection": [
        Transition("depart_outbound_connection", 1.0, "triangular", {"low": 10, "mode": 18, "high": 30}),
    ],
    "depart_outbound_connection": [
        Transition("arrive_ito_connection", 1.0, "normal", {"mean": 39, "std": 6, "low": 28, "high": 58}),
    ],
    "arrive_ito_connection": [
        Transition("baggage_claim_outbound", 0.55, "triangular", {"low": 9, "mode": 18, "high": 35}),
        Transition("exit_airport_outbound", 0.45, "triangular", {"low": 4, "mode": 9, "high": 18}),
    ],
    "arrive_ito": [
        Transition("baggage_claim_outbound", 0.55, "triangular", {"low": 8, "mode": 17, "high": 32}),
        Transition("exit_airport_outbound", 0.45, "triangular", {"low": 4, "mode": 8, "high": 16}),
    ],
    "baggage_claim_outbound": [
        Transition("exit_airport_outbound", 1.0, "triangular", {"low": 4, "mode": 8, "high": 18}),
    ],
    "exit_airport_outbound": [
        Transition("stay_in_hilo", 1.0, "uniform", {"a": 20, "b": 120}),
    ],
    "stay_in_hilo": [
        Transition("check_in_return", 1.0, "uniform", {"a": 120, "b": 60 * 24 * 7}),
    ],

    "check_in_return": [
        Transition("bag_drop_return", 0.58, "triangular", {"low": 4, "mode": 8, "high": 18}),
        Transition("security_return", 0.42, "triangular", {"low": 5, "mode": 10, "high": 20}),
    ],
    "bag_drop_return": [
        Transition("security_return", 1.0, "triangular", {"low": 5, "mode": 9, "high": 18}),
    ],
    "security_return": [
        Transition("gate_wait_return", 1.0, "normal", {"mean": 16, "std": 6, "low": 5, "high": 35}),
    ],
    "gate_wait_return": [
        Transition("return_cancel", 0.015, "uniform", {"a": 20, "b": 90}),
        Transition("return_delay", 0.16, "triangular", {"low": 12, "mode": 26, "high": 70}),
        Transition("board_return", 0.825, "triangular", {"low": 10, "mode": 26, "high": 45}),
    ],
    "return_delay": [
        Transition("return_cancel", 0.03, "uniform", {"a": 20, "b": 90}),
        Transition("board_return", 0.97, "lognormal", {"mean": 3.30, "sigma": 0.36, "low": 12, "high": 110}),
    ],
    "return_cancel": [
        Transition("rebook_return", 1.0, "lognormal", {"mean": 5.15, "sigma": 0.45, "low": 60, "high": 720}),
    ],
    "rebook_return": [
        Transition("check_in_return", 1.0, "uniform", {"a": 180, "b": 60 * 24 * 2}),
    ],
    "board_return": [
        Transition("depart_ito", 1.0, "triangular", {"low": 8, "mode": 15, "high": 25}),
    ],
    "depart_ito": [
        Transition("change_planes_return", 0.03, "uniform", {"a": 30, "b": 55}),
        Transition("go_around_hnl", 0.002, "uniform", {"a": 35, "b": 52}),  # about 1 in 500
        Transition("arrive_hnl", 0.968, "normal", {"mean": 44, "std": 5, "low": 34, "high": 62}),
    ],
    "go_around_hnl": [
        Transition("arrive_hnl", 1.0, "triangular", {"low": 12, "mode": 18, "high": 28}),
    ],
    "change_planes_return": [
        Transition("board_return_connection", 1.0, "lognormal", {"mean": 3.85, "sigma": 0.35, "low": 25, "high": 120}),
    ],
    "board_return_connection": [
        Transition("depart_return_connection", 1.0, "triangular", {"low": 10, "mode": 18, "high": 30}),
    ],
    "depart_return_connection": [
        Transition("arrive_hnl_connection", 1.0, "normal", {"mean": 39, "std": 6, "low": 28, "high": 58}),
    ],
    "arrive_hnl_connection": [
        Transition("baggage_claim_return", 0.55, "triangular", {"low": 9, "mode": 18, "high": 35}),
        Transition("exit_airport_return", 0.45, "triangular", {"low": 4, "mode": 9, "high": 18}),
    ],
    "arrive_hnl": [
        Transition("baggage_claim_return", 0.55, "triangular", {"low": 8, "mode": 17, "high": 32}),
        Transition("exit_airport_return", 0.45, "triangular", {"low": 4, "mode": 8, "high": 16}),
    ],
    "baggage_claim_return": [
        Transition("exit_airport_return", 1.0, "triangular", {"low": 4, "mode": 8, "high": 18}),
    ],
    "exit_airport_return": [
        Transition("trip_complete", 1.0, "triangular", {"low": 8, "mode": 18, "high": 40}),
    ],
    "trip_complete": [],
}


AIRPORT_NAMES = {
    "HNL": "Daniel K. Inouye International Airport",
    "ITO": "Hilo International Airport",
}

AIRLINES = ["Hawaiian Airlines", "Southwest Airlines", "Mokulele (codeshare example)"]
AIRCRAFT = ["Boeing 717", "Airbus A321neo", "Boeing 737-800"]
TERMINALS = {"HNL": ["T1", "T2"], "ITO": ["Main"]}
GATES = {
    "HNL": ["A1", "A2", "B4", "B6", "C3", "C5"],
    "ITO": ["1", "2", "3", "4"],
}


def weighted_choice(options: List[Transition]) -> Optional[Transition]:
    if not options:
        return None
    total = sum(t.weight for t in options)
    pick = random.uniform(0, total)
    running = 0.0
    for option in options:
        running += option.weight
        if pick <= running:
            return option
    return options[-1]


def sample_minutes(transition: Transition) -> int:
    d = transition.dist
    p = transition.params

    if d == "uniform":
        value = random.uniform(p["a"], p["b"])

    elif d == "triangular":
        value = random.triangular(p["low"], p["high"], p["mode"])

    elif d == "normal":
        while True:
            value = random.gauss(p["mean"], p["std"])
            if p["low"] <= value <= p["high"]:
                break

    elif d == "lognormal":
        while True:
            value = random.lognormvariate(p["mean"], p["sigma"])
            if p["low"] <= value <= p["high"]:
                break

    else:
        raise ValueError(f"Unsupported distribution type: {d}")

    return max(1, int(round(value)))


def random_datetime(start_dt: datetime, end_dt: datetime) -> datetime:
    total_seconds = int((end_dt - start_dt).total_seconds())
    offset = random.randint(0, total_seconds)
    return start_dt + timedelta(seconds=offset)


def json_dumps(value: dict) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def iso_sql(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def make_case_id(case_num: int) -> str:
    return f"flightcase:HNL-ITO-HNL:{case_num:09d}"


def make_flight_number(_: str, __: str) -> str:
    prefix = random.choice(["HA", "WN", "MW"])
    return f"{prefix}{random.randint(100, 9999)}"


def pick_gate(airport_code: str) -> str:
    return random.choice(GATES[airport_code])


def pick_terminal(airport_code: str) -> str:
    return random.choice(TERMINALS[airport_code])


def trip_days() -> int:
    return random.choice([1, 2, 3, 4, 5])


def checked_bag_count() -> int:
    return random.choices([0, 1, 2], weights=[0.45, 0.45, 0.10], k=1)[0]


def travel_purpose() -> str:
    return random.choice(["business", "family", "medical", "leisure"])


def passenger_count() -> int:
    return random.choices([1, 2, 3], weights=[0.75, 0.20, 0.05], k=1)[0]


def build_case_properties(case_num: int) -> dict:
    bags = checked_bag_count()
    days = trip_days()
    pax = passenger_count()

    flight_outbound = outbound_flight_cost()
    flight_return = return_flight_cost()
    bag_cost = baggage_cost_total(bags)
    meals = meal_cost_total()

    return {
        "case_label": "HNL-ITO round trip",
        "trip_type": "round_trip",
        "origin_airport": "HNL",
        "origin_airport_name": AIRPORT_NAMES["HNL"],
        "destination_airport": "ITO",
        "destination_airport_name": AIRPORT_NAMES["ITO"],
        "return_destination_airport": "HNL",
        "days_in_hilo": days,
        "checked_bag_count": bags,
        "has_checked_bags": bags > 0,
        "passenger_count": pax,
        "travel_purpose": travel_purpose(),
        "case_sequence_number": case_num,

        "flight_cost_outbound": flight_outbound,
        "flight_cost_return": flight_return,
        "flight_cost_total": round(flight_outbound + flight_return, 2),
        "baggage_cost_total": round(bag_cost, 2),
        "meal_cost_total": round(meals, 2),
        "trip_cost_total": round(flight_outbound + flight_return + bag_cost + meals, 2),
    }

def outbound_flight_cost() -> float:
    return round(random.triangular(85, 210, 125), 2)

def return_flight_cost() -> float:
    return round(random.triangular(85, 210, 125), 2)

def baggage_cost_total(bag_count: int) -> float:
    # Simple demo pricing model.
    # 1st bag $35, 2nd bag $45
    if bag_count <= 0:
        return 0.0
    if bag_count == 1:
        return 35.0
    return 80.0

def meal_cost_total() -> float:
    # Most interisland trips will be zero, but allow some snack/meal purchases.
    return round(random.choices(
        [0.0, 8.50, 12.00, 16.50, 24.00],
        weights=[0.55, 0.15, 0.12, 0.10, 0.08],
        k=1
    )[0], 2)


def build_event_context(event_name: str, case_props: dict) -> dict:
    outbound_flight = {
        "direction": "outbound",
        "airport_from": "HNL",
        "airport_to": "ITO",
        "airport_from_name": AIRPORT_NAMES["HNL"],
        "airport_to_name": AIRPORT_NAMES["ITO"],
        "airline": random.choice(AIRLINES),
        "flight_number": make_flight_number("HNL", "ITO"),
        "terminal": pick_terminal("HNL"),
        "gate": pick_gate("HNL"),
        "aircraft_type": random.choice(AIRCRAFT),
    }

    return_flight = {
        "direction": "return",
        "airport_from": "ITO",
        "airport_to": "HNL",
        "airport_from_name": AIRPORT_NAMES["ITO"],
        "airport_to_name": AIRPORT_NAMES["HNL"],
        "airline": random.choice(AIRLINES),
        "flight_number": make_flight_number("ITO", "HNL"),
        "terminal": pick_terminal("ITO"),
        "gate": pick_gate("ITO"),
        "aircraft_type": random.choice(AIRCRAFT),
    }

    if "_outbound" in event_name or event_name in {
        "depart_hnl", "arrive_ito", "go_around_ito"
    }:
        ctx = dict(outbound_flight)
    elif "_return" in event_name or event_name in {
        "depart_ito", "arrive_hnl", "go_around_hnl"
    }:
        ctx = dict(return_flight)
    else:
        ctx = {
            "direction": "case_level",
            "airport_from": case_props["origin_airport"],
            "airport_to": case_props["destination_airport"],
        }

    if event_name == "book_trip":
        ctx.update({
            "booking_channel": random.choice(["web", "mobile_app", "travel_agent"]),
            "fare_class": random.choice(["main", "extra_comfort", "business_like_demo"]),
            "round_trip": True,
        })
    elif event_name == "stay_in_hilo":
        ctx.update({
            "days_in_hilo": case_props["days_in_hilo"],
            "lodging_type": random.choice(["hotel", "family", "vacation_rental"]),
        })
    elif event_name in {"outbound_delay", "return_delay"}:
        expected_delay = random.randint(15, 90)
        ctx.update({
            "delay_reason": random.choice(["late_arrival", "weather", "crew", "maintenance"]),
            "expected_delay_minutes": expected_delay,
        })

    elif event_name in {"outbound_cancel", "return_cancel"}:
        ctx.update({
            "cancel_reason": random.choice(["weather", "maintenance", "crew", "equipment"]),
            "rebooking_required": True,
        })

    elif event_name in {"change_planes_outbound", "change_planes_return"}:
        ctx.update({
            "connection_airport": random.choice(["OGG", "KOA"]),
            "connection_required": True,
        })

    elif event_name in {"go_around_ito", "go_around_hnl"}:
        ctx.update({
            "go_around_reason": random.choice(["weather", "runway_traffic", "unstable_approach"]),
            "additional_flight_minutes_expected": random.randint(10, 25),
        })

    return ctx


def build_event_actual_properties(
    event_name: str,
    event_dt: datetime,
    case_props: dict,
    context: dict,
) -> dict:
    props = {
        "event_name": event_name,
        "event_description": EVENT_DEFINITIONS[event_name],
        "event_timestamp": iso_sql(event_dt),
        "trip_type": case_props["trip_type"],
        "origin_airport": case_props["origin_airport"],
        "destination_airport": case_props["destination_airport"],
        "passenger_count": case_props["passenger_count"],
        "checked_bag_count": case_props["checked_bag_count"],
        "travel_purpose": case_props["travel_purpose"],
    }
    props.update(context)
    return props


def generate_case_rows(case_num: int) -> List[dict]:
    case_id = make_case_id(case_num)
    case_props = build_case_properties(case_num)

    book_dt = random_datetime(START_DATE, END_DATE)
    date_added = datetime.now()

    rows: List[dict] = []
    current_event = "book_trip"
    current_dt = book_dt

    while current_event:
        event_description = EVENT_DEFINITIONS[current_event]
        event_context = build_event_context(current_event, case_props)
        actual_props = build_event_actual_properties(current_event, current_dt, case_props, event_context)

        row = {
            "ImportEventID": None,
            "SourceID": SOURCE_ID,
            "CaseID": case_id,
            "Event": current_event,
            "EventDescription": event_description,
            "EventDate": iso_sql(current_dt),
            "CaseProperties": json_dumps(case_props),
            "CaseTargetProperties": None,
            "EventActualProperties": json_dumps(actual_props),
            "EventExpectedProperties": None,
            "EventAggregationProperties": None,
            "EventIntendedProperties": None,
            "CaseType": CASE_TYPE,
            "NaturalKey_SourceColumn_ID": NATURALKEY_SOURCECOLUMN_ID,
            "AccessBitmap": ACCESS_BITMAP,
            "DateAdded": iso_sql(date_added),
            "ValidationBitmap": None,
        }
        rows.append(row)

        next_options = TRANSITIONS.get(current_event, [])
        if not next_options:
            break

        transition = weighted_choice(next_options)
        if transition is None:
            break

        delta_minutes = sample_minutes(transition)
        current_dt = current_dt + timedelta(minutes=delta_minutes)
        current_event = transition.next_event

    return rows


def write_csv(rows: List[dict], output_file: Path) -> None:
    output_file.parent.mkdir(parents=True, exist_ok=True)

    fieldnames = [
        "ImportEventID",
        "SourceID",
        "CaseID",
        "Event",
        "EventDescription",
        "EventDate",
        "CaseProperties",
        "CaseTargetProperties",
        "EventActualProperties",
        "EventExpectedProperties",
        "EventAggregationProperties",
        "EventIntendedProperties",
        "CaseType",
        "NaturalKey_SourceColumn_ID",
        "AccessBitmap",
        "DateAdded",
        "ValidationBitmap",
    ]

    with output_file.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    all_rows: List[dict] = []
    for case_num in range(1, NUM_CASES + 1):
        all_rows.extend(generate_case_rows(case_num))

    write_csv(all_rows, OUTPUT_FILE)

    print(f"Wrote {len(all_rows):,} staged event rows")
    print(f"for {NUM_CASES:,} cases")
    print(f"to {OUTPUT_FILE.resolve()}")


if __name__ == "__main__":
    main()