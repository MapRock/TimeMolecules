"""
export_markov_to_graphs.py
==========================

Purpose:
    Exports Markov model transition data from TimeSolution into three useful 
    graph formats:
    - Cypher script for Neo4j (interactive graph exploration)
    - PlantUML diagram (clean, embeddable state-transition diagrams)
    - RDF/Turtle (.ttl)    → OWL/RDF semantic representation (new)

    This makes Markov models from Time Molecules much easier to visualize 
    and share with stakeholders, analysts, and AI agents.

How It Works:
    1. Connects to TimeSolution using the shared TimeSolutionDAL
    2. Calls dbo.MarkovProcess2 with the specified event set and date range
    3. Generates:
        - A .cypher file (ready to import into Neo4j)
        - A .puml file (PlantUML state diagram)
        - A .ttl file (RDF/Turtle semantic representation)
    4. Files are saved in DEFAULT_OUTPUT_DIR/markov_exports/

Key Features:
    - Uses the tutorials/.env for configuration
    - Supports any event set and date range
    - Produces both machine-readable (Cypher) and human-readable (PlantUML) output
    - Clean, stable filenames with timestamps

Usage:
    python export_markov_to_graphs.py

Example:
    python export_markov_to_graphs.py "arrive,greeted,seated,ordered" "2024-01-01" "2025-12-31"

Output:
    Creates files such as:
    - markov_model_20260505_143022.cypher
    - markov_model_20260505_143022.puml

Part of the Time Molecules tutorials:
https://github.com/MapRock/TimeMolecules/tree/main/tutorials/markov_outputs_graph_format


"""

import os
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from datetime import datetime

from shared.time_solution import TimeSolutionDAL
from dotenv import load_dotenv

# Force the tutorials .env
tutorials_env = Path(r"C:\MapRock\TimeMolecules\tutorials\.env")
if tutorials_env.exists():
    load_dotenv(tutorials_env, override=True)
    print(f"✅ FORCED .env FROM TUTORIALS: {tutorials_env}")
else:
    print(f"❌ Could not find tutorials/.env at {tutorials_env}")


def export_markov_model(
    event_set: str,
    start_datetime: str,
    end_datetime: str,
    output_subdir: str = "markov_exports"
):
    dal = TimeSolutionDAL()

    model_description = f"Markov model for events: {event_set} from {start_datetime} to {end_datetime}"
    
    sql = """
        EXEC dbo.MarkovProcess2
        @EventSet=?,
        @StartDateTime=?,
        @EndDateTime=?
    """
    params = (event_set, start_datetime, end_datetime)
    
    print(f"🔄 Fetching {model_description} from TimeSolution...")
    transitions = dal.execute_query(sql, params)
    
    if not transitions:
        print("❌ No transitions returned.")
        return

    output_dir = Path(os.getenv("DEFAULT_OUTPUT_DIR", "output")) / output_subdir
    output_dir.mkdir(parents=True, exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # 1. Cypher (Neo4j)
    cypher_path = output_dir / f"markov_model_{timestamp}.cypher"
    # ... (your existing Cypher code) ...
    with open(cypher_path, "w", encoding="utf-8") as f:
        f.write(f"// Time Molecules {model_description} – {timestamp}\n\n")
        f.write("// Nodes\n")
        events = {t["Event1A"] for t in transitions} | {t["EventB"] for t in transitions}
        for event in events:
            f.write(f'CREATE (e:Event {{name: "{event}"}});\n')
        
        f.write("\n// Transitions with probabilities\n")
        for t in transitions:
            f.write(
                f'MATCH (a:Event {{name: "{t["Event1A"]}"}}), '
                f'(b:Event {{name: "{t["EventB"]}"}}) '
                f'CREATE (a)-[r:TRANSITION {{'
                f'probability: {t.get("Prob", 0):.6f}, '
                f'count: {t.get("Rows", 0)}'
                f'}}]->(b);\n'
            )
    print(f"✅ Cypher saved → {cypher_path}")

    # 2. PlantUML
    puml_path = output_dir / f"markov_model_{timestamp}.puml"
    # ... (your existing PlantUML code) ...
    with open(puml_path, "w", encoding="utf-8") as f:
        f.write("@startuml\nskinparam shadowing false\nskinparam monochrome true\n\n")
        f.write("state \"Start\" as start\n\n")
        for t in transitions:
            prob = t.get("Prob", 0)
            f.write(f'{t["Event1A"]} --> {t["EventB"]} : {prob:.1%}\n')
        f.write("\n@enduml\n")
    print(f"✅ PlantUML saved → {puml_path}")

    # 3. NEW: OWL/RDF Turtle (.ttl)
    ttl_path = output_dir / f"markov_model_{timestamp}.ttl"
    with open(ttl_path, "w", encoding="utf-8") as f:
        f.write("@prefix ex: <http://example.org/timemolecules/> .\n")
        f.write("@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n")
        f.write("@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n\n")

        f.write("# Events\n")
        events = {t["Event1A"] for t in transitions} | {t["EventB"] for t in transitions}
        for event in sorted(events):
            f.write(f'ex:{event} a ex:Event ;\n')
            f.write(f'    rdfs:label "{event}" .\n\n')

        f.write("# Transitions\n")
        for t in transitions:
            prob = t.get("Prob", 0)
            f.write(f'ex:{t["Event1A"]} ex:transitionsTo ex:{t["EventB"]} ;\n')
            f.write(f'    ex:probability "{prob}"^^xsd:decimal .\n\n')

    print(f"✅ RDF/Turtle (OWL) saved → {ttl_path}")
    print("   (Open in Protégé, RDF editors, or any triple store)")

    print(f"\nAll files saved in: {output_dir}")


if __name__ == "__main__":
    # Change these values as needed

    # For example, a very simple model with just three events, a partial restaurant visit.
    export_markov_model(
        event_set='arrive,greeted,seated',
        start_datetime='2023-01-01',
        end_datetime='2025-12-31'
    )