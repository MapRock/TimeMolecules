"""
TimeMolecules AI Agent Demo / Index Builder
Part of tutorials/ai_agent_skills

- build_qdrant_index.py   → creates/updates the Qdrant collection from TimeSolution metadata + llm_prompts
- time_molecules_agent_demo.py → Tkinter GUI for semantic search + LLM-grounded answers

Run build_qdrant_index.py first, then the demo.
Uses .env + local Qdrant folder.
"""
from qdrant_client import QdrantClient

import json
import os
import threading
from pathlib import Path
from tkinter import Tk, Label, Button, END, BOTH, X, Frame, LEFT, BooleanVar, Checkbutton, Spinbox, IntVar
from tkinter.scrolledtext import ScrolledText
from tkinter import ttk
import requests
import pandas as pd
from pandastable import Table

import ollama
import openai
from dotenv import load_dotenv


# ----------------------------
# Load .env (search upward)
# ----------------------------
current = Path(__file__).resolve()
env_path = None

for parent in [current.parent, *current.parents]:
    candidate = parent / ".env"
    if candidate.exists():
        env_path = candidate
        break

if env_path:
    load_dotenv(env_path)
    print(f"✅ Loaded .env from: {env_path}")
else:
    print("⚠️ .env not found. Falling back to system environment variables.")


# ----------------------------
# Config
# ----------------------------

llm=os.getenv("LLM", "ollama").lower() 


COLLECTION_NAME = os.getenv("QDRANT_COLLECTION_NAME", "time_molecules_directory")
QDRANT_PATH = os.getenv("QDRANT_PATH", "c:/MapRock/TimeMolecules/qdrant_data_ollama")

OLLAMA_HOST = os.getenv("OLLAMA_HOST", None)
OLLAMA_EMBED_MODEL = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")
OLLAMA_CHAT_MODEL = os.getenv("OLLAMA_CHAT_MODEL", "llama3.2")
RESULTS_LIMIT = int(os.getenv("RESULTS_LIMIT", "5"))
ctx = int(os.getenv("OLLAMA_CTX", 8192))

# openai config variables.
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
CHATGPT_MODEL = os.getenv("CHATGPT_MODEL", "gpt-4o-mini")
MAX_TOKENS = int(os.getenv("CHATGPT_MAX_RESPONSE_TOKENS", "500"))

if llm== "openai":
    if not OPENAI_API_KEY:
        raise RuntimeError("OPENAI_API_KEY must be set in .env or environment variables to use OpenAI as LLM.")
    else:
        openai.api_key = OPENAI_API_KEY



SYSTEM_PROMPT_URL = (
    "https://raw.githubusercontent.com/MapRock/TimeMolecules/main/"
    "tutorials/ai_agent_skills/system_prompt.txt"
)

PROMPT_TEMPLATE_URL = (
    "https://raw.githubusercontent.com/MapRock/TimeMolecules/main/"
    "tutorials/ai_agent_skills/prompt_template.txt"
)

class BaseAgent:
    def __init__(self, name, llm_client):
    
        self.name = name
        self.llm_client = llm_client

    def run(self, context):
        raise NotImplementedError("Subclasses must implement the run() method.")
    
    def embed_text(self,text: str) -> list[float]:
        response = OLLAMA_CLIENT.embed(model=OLLAMA_EMBED_MODEL, input=text)

        embeddings = response.get("embeddings")
        if not embeddings or not embeddings[0]:
            raise ValueError("Ollama returned no embedding.")

        return embeddings[0]
    
    def ask_llm(self,prompt: str, context: str) -> str:

        print(f"Calling {llm} chat with model: {OLLAMA_CHAT_MODEL}")
        print(f"Prompt Length:\n{len(prompt)}\n")
        print(f"Context length: {len(context)}")

        user_prompt = prompt_template.replace("{prompt}", prompt).replace("{context}", context)


        if llm == "openai":
            response = openai.ChatCompletion.create(
                model=CHATGPT_MODEL,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                max_tokens=MAX_TOKENS,
            )
            response_message = response["choices"][0]["message"]["content"].strip()

        elif llm == "ollama":
            response = OLLAMA_CLIENT.chat(
                model=OLLAMA_CHAT_MODEL,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                options={"num_ctx": ctx}
            )
            message = response.get("message", {})
            response_message = message.get("content", "").strip()

        else:
            raise ValueError(f"Unsupported llm: {llm}")

        return response_message

class TaskContext:
    def __init__(self, user_prompt):
        self.user_prompt = user_prompt
        self.goal = None
        self.process = []
        self.current_step = None
        self.retrieved_hits = []
        self.link_contents = []
        self.metadata_findings = []
        self.sql_attempts = []
        self.sql_results = []
        self.errors = []
        self.final_answer = None

class GuidanceAgent(BaseAgent):
    def run(self, context):
        # produce process / plan / likely objects
        pass

class DiscoveryAgent(BaseAgent):
    def run(self, context):
        # inspect links, metadata, properties, object definitions
        pass

class SQLAgent(BaseAgent):
    def run(self, context):
        # draft, validate, execute, repair SQL
        pass

class PrimaryAgent(BaseAgent):
    def __init__(self, name, llm_client, guidance_agent, discovery_agent, sql_agent):
        super().__init__(name, llm_client)
        self.guidance_agent = guidance_agent
        self.discovery_agent = discovery_agent
        self.sql_agent = sql_agent

    def run(self, context):
        # orchestrate subagents based on task type and current state
        pass

    def format_hits_for_display(self,hits) -> str:
        """Now shows SampleCode (indented) for stored procs/functions."""
        if not hits:
            return "No matches found."

        lines = []
        for i, hit in enumerate(hits, start=1):
            payload = hit.payload or {}
            obj_name = payload.get('ObjectName', '<unknown>')
            obj_type = payload.get('ObjectType', '')

            lines.append(f"{i}. {obj_name} [{obj_type}]")
            lines.append(f"   Score: {round(getattr(hit, 'score', 0), 4)}")

            if payload.get("Description"):
                lines.append(f"   Description: {payload.get('Description')}")

            if payload.get("Utilization"):
                lines.append(f"   Utilization: {payload.get('Utilization')}")

            if obj_type in ("SQL_STORED_PROCEDURE", "SQL_SCALAR_FUNCTION",
                            "SQL_TABLE_VALUED_FUNCTION", "SQL_INLINE_TABLE_VALUED_FUNCTION"):
                # Parameters
                if payload.get("ParametersJson"):
                    lines.append("   Parameters:")
                    for line in safe_json_pretty(payload["ParametersJson"]).splitlines():
                        lines.append(f"      {line}")
                else:
                    lines.append("   Parameters: (none)")

                # SampleCode
                sample = payload.get("SampleCode", "").strip()
                if sample:
                    lines.append("   SampleCode:")
                    for line in sample.splitlines():
                        lines.append(f"      {line}")
                else:
                    lines.append("   SampleCode: (none)")

            lines.append("")

        return "\n".join(lines).strip()

    def search_metadata(self, prompt: str, limit: int = RESULTS_LIMIT):
        client = get_qdrant_client()
        try:
            query_vector = self.embed_text(prompt)
            results = client.query_points(
                collection_name=COLLECTION_NAME,
                query=query_vector,
                limit=limit,
                with_payload=True,
            ).points
            return results
        finally:
            client.close()




# ----------------------------
# Ollama helpers
# ----------------------------
def get_ollama_client():
    if OLLAMA_HOST:
        return ollama.Client(host=OLLAMA_HOST)
    return ollama.Client()


OLLAMA_CLIENT = get_ollama_client()





def load_prompt(url: str, timeout: int = 15) -> str:
    try:
        resp = requests.get(url, timeout=timeout)
        resp.raise_for_status()
        text = resp.text.strip()
        if not text:
            raise RuntimeError(f"Prompt at {url} is empty.")
        return text
    except Exception as e:
        raise RuntimeError(f"Could not load prompt from {url}: {e}") from e


system_prompt = load_prompt(SYSTEM_PROMPT_URL)
prompt_template = load_prompt(PROMPT_TEMPLATE_URL)




# ----------------------------
# Qdrant helpers
# ----------------------------
def get_qdrant_client() -> QdrantClient:
    return QdrantClient(path=QDRANT_PATH)


def ensure_collection_exists():
    client = get_qdrant_client()
    try:
        if not client.collection_exists(collection_name=COLLECTION_NAME):
            raise RuntimeError(
                f"Qdrant collection '{COLLECTION_NAME}' does not exist at {QDRANT_PATH}. "
                f"Build it first with the separate indexing script, qdrant_demo_ollama.py."
            )
    finally:
        client.close()





# ----------------------------
# Prompt grounding
# ----------------------------
# ---------------------------- 
# Prompt grounding (UPDATED)
# ----------------------------

def safe_json_pretty(text_value: str) -> str:
    if not text_value:
        return ""
    try:
        parsed = json.loads(text_value)
        return json.dumps(parsed, indent=2)
    except Exception:
        return str(text_value)


def build_context_from_hits(hits) -> str:
    """Now includes SampleCode for procs/functions so the LLM sees real usage examples."""
    parts = []

    for i, hit in enumerate(hits, start=1):
        payload = hit.payload or {}
        object_name = payload.get("ObjectName", "")
        object_type = payload.get("ObjectType", "")
        description = payload.get("Description", "")
        utilization = payload.get("Utilization", "")
        params_json = payload.get("ParametersJson", "")
        sample_code = payload.get("SampleCode", "")

        block = f"""
Match {i}
Score: {getattr(hit, "score", "")}
Object Name: {object_name}
Object Type: {object_type}
Description: {description}
Utilization: {utilization}
"""

        if object_type in ("SQL_STORED_PROCEDURE", "SQL_SCALAR_FUNCTION",
                           "SQL_TABLE_VALUED_FUNCTION", "SQL_INLINE_TABLE_VALUED_FUNCTION"):
            if params_json:
                block += f"\nParameters:\n{safe_json_pretty(params_json)}"
            else:
                block += "\nParameters: (none)"

            if sample_code:
                block += f"\n\nSampleCode:\n{sample_code.strip()}"

        parts.append(block.strip())

    return "\n\n" + ("\n\n" + ("-" * 70) + "\n\n").join(parts)




# ----------------------------
# UI (UPDATED with tabs + DataFrame support)
# ----------------------------
class TimeMoleculesUI:
    def __init__(self, root: Tk):
        self.root = root
        self.root.title("Time Molecules Prompt UI (Query Qdrant + Ollama)")
        self.root.geometry("1100x820")

        self.primeagent = PrimaryAgent(
            name="PrimeAgent",
            llm_client=get_ollama_client(),
            guidance_agent=GuidanceAgent("GuidanceAgent", get_ollama_client()),
            discovery_agent=DiscoveryAgent("DiscoveryAgent", get_ollama_client()),
            sql_agent=SQLAgent("SQLAgent", get_ollama_client())
        )


        top = Frame(root)
        top.pack(fill=X, padx=10, pady=10)

        self.mode_label = Label(
            top,
            text=(
                f"Qdrant collection: {COLLECTION_NAME} | "
                f"Ollama chat model: {OLLAMA_CHAT_MODEL} | "
                f"Ollama embed model: {OLLAMA_EMBED_MODEL}"
            ),
            anchor="w",
            justify="left",
        )
        self.mode_label.pack(fill=X)

        prompt_label = Label(root, text="Prompt:")
        prompt_label.pack(anchor="w", padx=10)

        self.prompt_box = ScrolledText(root, height=8, wrap="word")
        self.prompt_box.pack(fill=X, padx=10, pady=5)
        self.prompt_box.insert("1.0", "What procedure computes a Markov model but does not persist it?")

        button_frame = Frame(root)
        button_frame.pack(fill=X, padx=10, pady=5)

        self.ask_button = Button(button_frame, text="Ask", command=self.on_ask)
        self.ask_button.pack(side=LEFT, padx=(0, 12))

        self.results_limit_var = IntVar(value=RESULTS_LIMIT)
        self.results_limit_spin = Spinbox(
            button_frame, from_=1, to=50, width=4, textvariable=self.results_limit_var
        )
        self.results_limit_spin.pack(side=LEFT, padx=(0, 12))

        self.use_llm_var = BooleanVar(value=True)
        self.use_llm_checkbox = Checkbutton(
            button_frame,
            text=f"Use {llm} to summarize retrieved hits",
            variable=self.use_llm_var,
        )
        self.use_llm_checkbox.pack(side=LEFT)

        self.status_label = Label(root, text="Ready.", anchor="w", justify="left")
        self.status_label.pack(fill=X, padx=10, pady=5)

        self.spinner = ttk.Progressbar(root, mode="indeterminate", length=220)
        self.spinner.pack(anchor="w", padx=10, pady=(0, 8))

        hits_label = Label(root, text="Retrieved Objects:")
        hits_label.pack(anchor="w", padx=10)

        self.hits_box = ScrolledText(root, height=14, wrap="word")
        self.hits_box.pack(fill=BOTH, expand=False, padx=10, pady=5)

        # ================== NEW: TABBED RESULTS AREA ==================
        results_label = Label(root, text="Results:")
        results_label.pack(anchor="w", padx=10, pady=(10, 0))

        self.results_notebook = ttk.Notebook(root)
        self.results_notebook.pack(fill=BOTH, expand=True, padx=10, pady=5)

        # Tab 1: Text Answer
        self.answer_frame = Frame(self.results_notebook)
        self.results_notebook.add(self.answer_frame, text="Answer")
        self.answer_box = ScrolledText(self.answer_frame, wrap="word")
        self.answer_box.pack(fill=BOTH, expand=True)

        # Tab 2: Data Table (will hold pandastable)
        self.table_frame = Frame(self.results_notebook)
        self.results_notebook.add(self.table_frame, text="Query Results")
        self.table = None  # will be created when we have data

    def start_spinner(self):
        self.spinner.start(10)

    def stop_spinner(self):
        self.spinner.stop()

    def set_status(self, text: str):
        self.status_label.config(text=text)
        self.root.update_idletasks()

    # New helper: show text in Answer tab
    def show_text(self, text: str):
        self.answer_box.delete("1.0", END)
        self.answer_box.insert("1.0", text)
        self.results_notebook.select(self.answer_frame)   # switch to Answer tab

    # New helper: show DataFrame as nice table
    def show_dataframe(self, df: pd.DataFrame):
        # Clear previous table if it exists
        for widget in self.table_frame.winfo_children():
            widget.destroy()

        if df is None or df.empty:
            Label(self.table_frame, text="No data returned from query.").pack()
            return

        self.table = Table(self.table_frame, dataframe=df,
                           showtoolbar=True, showstatusbar=True)
        self.table.show()
        self.results_notebook.select(self.table_frame)   # switch to table tab

    def on_ask(self):
        prompt = self.prompt_box.get("1.0", END).strip()
        if not prompt:
            self.set_status("Enter a prompt first.")
            return

        try:
            results_limit = max(1, int(self.results_limit_var.get()))
        except Exception:
            results_limit = RESULTS_LIMIT

        def worker():
            try:
                self.ask_button.config(state="disabled")
                self.start_spinner()
                self.answer_box.delete("1.0", END)
                # clear old table
                for widget in self.table_frame.winfo_children():
                    widget.destroy()

                self.set_status("Checking Qdrant collection...")
                ensure_collection_exists()

                self.set_status("Embedding prompt and searching Qdrant...")
                hits = self.primeagent.search_metadata(prompt, limit=results_limit)

                self.hits_box.delete("1.0", END)
                self.hits_box.insert("1.0", self.primeagent.format_hits_for_display(hits))

                if not self.use_llm_var.get():
                    self.show_text("Retrieved hits shown above. Ollama summarization is turned off.")
                    self.set_status("Done.")
                    return

                context = build_context_from_hits(hits)

                self.set_status("Calling LLM...")
                answer = self.primeagent.ask_llm(prompt, context)

                # === NEW: Try to extract and run SQL if present ===
                sql = self._extract_sql(answer)
                if sql:
                    self.set_status("Executing SQL query...")
                    df = self.execute_sql(sql)          # ← your DB logic here
                    if df is not None:
                        self.show_dataframe(df)
                        self.show_text(answer)          # keep explanation too
                        self.set_status("Done (SQL executed).")
                        return

                # Normal text answer (no SQL)
                self.show_text(answer)
                self.set_status("Done.")

            except Exception as e:
                self.show_text(f"Error:\n{e}")
                self.set_status(f"Error: {e}")
            finally:
                self.ask_button.config(state="normal")
                self.stop_spinner()

        threading.Thread(target=worker, daemon=True).start()

    # Simple SQL extractor (looks for ```sql ... ``` block)
    def _extract_sql(self, text: str) -> str | None:
        import re
        match = re.search(r"```sql\s*(.*?)\s*```", text, re.DOTALL | re.IGNORECASE)
        if match:
            return match.group(1).strip()
        # fallback: if the whole answer looks like a SELECT statement
        if text.strip().upper().startswith(("SELECT", "WITH")):
            return text.strip()
        return None

    # ================== YOUR SQL EXECUTION GOES HERE ==================
    def execute_sql(self, sql: str) -> pd.DataFrame | None:
        """Replace this placeholder with your real database connection."""
        try:
            # EXAMPLE for SQLite (uncomment and modify):
            # import sqlite3
            # conn = sqlite3.connect("your_timesolution.db")
            # return pd.read_sql(sql, conn)

            # EXAMPLE for SQL Server / PostgreSQL with sqlalchemy:
            # from sqlalchemy import create_engine
            # engine = create_engine("mssql+pyodbc://...?driver=ODBC+Driver+17+for+SQL+Server")
            # return pd.read_sql(sql, engine)

            # For now just show what would be executed
            print("Would execute SQL:\n", sql)
            raise NotImplementedError("Implement your DB connection in execute_sql()")
        except Exception as e:
            self.show_text(f"SQL execution failed:\n{e}\n\nSQL was:\n{sql}")
            return None


# ----------------------------
# Main
# ----------------------------
def validate_config():
    if not QDRANT_PATH:
        raise RuntimeError("QDRANT_PATH is not set.")
    if not COLLECTION_NAME:
        raise RuntimeError("QDRANT_COLLECTION_NAME is not set.")



if __name__ == "__main__":

    # Paramteres

    # The running part.
    validate_config()

    root = Tk()
    app = TimeMoleculesUI(root)
    root.mainloop()