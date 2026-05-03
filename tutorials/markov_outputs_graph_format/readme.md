
# Visualizing Time Molecules Markov Models  
**Export to Neo4j (Cypher) + PlantUML**

One of the most powerful ways to understand a Markov process in Time Molecules is to **see** it. While Power BI and Tableau already give you excellent tabular and dashboard views, exporting the output of `dbo.MarkovProcess2` into graph formats lets you explore transitions, probabilities, and hidden-state patterns interactively.

This integration follows the same philosophy as the [Bayesian Prolog tutorial](../bayesian_prolog): take the rich SQL output of Time Molecules and turn it into a form that is both machine-readable and human-visual.

### Why Graphs Matter for Markov Models
- Markov transition tables become **Sankey diagrams**, **state machines**, or **network graphs** that reveal clusters of behavior, high-probability paths, and rare but important transitions.
- **Neo4j** gives you a live, queryable graph UI (Neo4j Browser or Bloom).
- **PlantUML** gives you beautiful, version-controlled diagrams you can embed in documentation, GitHub READMEs, or presentations.

### Files in This Folder
- `time_solution.py` – Generic Data Access Layer (DAL) for any SQL against TimeSolution (reused across the agent demo and other tutorials).
- `export_markov_to_graphs.py` – Ready-to-run script that calls `dbo.MarkovProcess2` and exports Cypher + PlantUML files.

### Prerequisites
- TimeSolution database with the `dbo.MarkovProcess2` stored procedure (included in the 2026 refresh).
- Python 3.10+ environment (the same one used by `time_molecules_agent_demo.py`).
- Your `.env` file configured with the usual TimeSolution connection settings plus `DEFAULT_OUTPUT_DIR`.
- Neo4j Desktop or the Time Molecules virtual machine (already documented in the main installation guide).

### Step 1: Run the Export

```bash
python export_markov_to_graphs.py
```

The script will:
- Connect to your TimeSolution database using the same environment variables as the AI Agent demo.
- Call `dbo.MarkovProcess2` with your chosen parameters (defaults are shown in the script).
- Write two files into your `DEFAULT_OUTPUT_DIR/markov_graphs/` folder:
  - `markov_..._YYYYMMDD_HHMMSS.cypher` – Neo4j import script
  - `markov_..._YYYYMMDD_HHMMSS.puml` – PlantUML diagram

### Step 2: View the Graphs (The UI Layer)

#### PlantUML (Instant, Lightweight Diagrams)
PlantUML turns the exported text file into clean state-transition diagrams instantly.

**Easiest option (no install):**
1. Go to https://www.plantuml.com/plantuml/uml
2. Drag-and-drop your `.puml` file or paste its contents.
3. Download the resulting PNG or SVG.

**Local installation (recommended for frequent use):**
1. Download the latest `plantuml.jar` from https://plantuml.com/download
2. Place it anywhere (e.g., `C:\Tools\plantuml.jar`)
3. Run from command line:
   ```bash
   java -jar plantuml.jar path/to/yourfile.puml
   ```
4. Or install the **PlantUML** extension in VS Code for live preview as you edit.

The generated diagrams are perfect for documentation, GitHub READMEs, presentations, or sharing with stakeholders.

#### Neo4j (Interactive Graph Exploration)
Neo4j is already installed and documented in the main Time Molecules virtual machine / installation guide.

**Quick start:**
1. Open Neo4j Desktop or Browser.
2. Create a new project/database (or use an existing one).
3. Copy the entire contents of the generated `.cypher` file.
4. Paste and run it in the Neo4j Browser.
5. Use queries like:
   ```cypher
   MATCH (a:Event)-[r:TRANSITION]->(b:Event)
   WHERE r.probability > 0.1
   RETURN a, r, b
   ```
6. Switch to **Neo4j Bloom** for beautiful, business-friendly graph visualizations.

### Next Steps & Customization
- Edit `export_markov_to_graphs.py` to change default parameters (`event_set`, dates, `min_occurrences`, etc.).
- Add support for the older `@ModelID` version of `MarkovProcess2` if needed.
- Extend the script to also export GraphML for Gephi/Cytoscape.
- Integrate the export directly into the AI Agent demo so an LLM can request “show me the Markov graph for customer journey X”.

You now have a complete visual layer on top of your Markov models — exactly the kind of high-end UI that makes Time Molecules intuitive for analysts, data scientists, and stakeholders alike.

Happy graphing!  
Questions or improvements? Open an issue in the repo.
