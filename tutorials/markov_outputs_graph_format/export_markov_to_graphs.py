# export_markov_to_graphs.py
import os
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from datetime import datetime

from shared.time_solution import TimeSolutionDAL

# Add the project root to Python's path so "from shared..." works from any subfolder


def export_markov_model(
    event_set: str,
    start_datetime: str,
    end_datetime: str,
    output_subdir: str = "markov_exports"
):
    dal = TimeSolutionDAL()

    model_description = f"Markov model for events: {event_set} from {start_datetime} to {end_datetime}"
    
    # Construct the EXEC call exactly as MarkovProcess2 expects
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

    # Use DEFAULT_OUTPUT_DIR from .env (same as your demo app)
    output_dir = Path(os.getenv("DEFAULT_OUTPUT_DIR", "output")) / output_subdir
    output_dir.mkdir(parents=True, exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # 1. Cypher export (Neo4j)
    cypher_path = output_dir / f"markov_model_{timestamp}.cypher"
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
                f'count: {t.get("Rows", 0)}, '
            #    f'confidence: {t.get("Confidence", 0):.4f}'
                f'}}]->(b);\n'
            )
    print(f"✅ Cypher saved → {cypher_path}")

    # 2. PlantUML export (state diagram)
    puml_path = output_dir / f"markov_model_{timestamp}.puml"
    with open(puml_path, "w", encoding="utf-8") as f:
        f.write("@startuml\nskinparam shadowing false\nskinparam monochrome true\n\n")
        f.write("state \"Start\" as start\n\n")
        for t in transitions:
            prob = t.get("Prob", 0)
            f.write(f'{t["Event1A"]} --> {t["EventB"]} : {prob:.1%}\n')
        f.write("\n@enduml\n")
    print(f"✅ PlantUML saved → {puml_path}")
    print("   Open at: https://www.plantuml.com/plantuml/uml")

if __name__ == "__main__":
    # Change event_set, start_datetime, and end_datetime to whatever you need
    export_markov_model('arrive,greeted,seated','2023-01-01', '2025-12-31')   # ← your event set and date range here
