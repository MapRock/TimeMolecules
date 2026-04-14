"""
TimeMolecules AI Agent Demo / Index Builder
Part of tutorials/ai_agent_skills

- build_qdrant_index.py   → creates/updates the Qdrant collection from TimeSolution metadata + llm_prompts
- time_molecules_agent_demo.py → Tkinter GUI for semantic search + LLM-grounded answers

Run build_qdrant_index.py first, then the demo.
Uses .env + local Qdrant folder.
"""
import re

from qdrant_client import QdrantClient
from qdrant_client.models import Filter, FieldCondition, MatchAny

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
import pyodbc

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

# Time Solution DB connection config (if you want to execute SQL against it)
SERVER = os.getenv("TIMESOLUTION_SERVER_NAME")
DATABASE = os.getenv("TIMESOLUTION_DATABASE_NAME")
CONN_DRIVER = os.getenv("TIMESOLUTION_CONNECTION_DRIVER", "ODBC Driver 18 for SQL Server")

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

FILTER_OBJECTTYPE_PROMPT_URL = (
    "https://raw.githubusercontent.com/MapRock/TimeMolecules/main/"
    "tutorials/ai_agent_skills/filter_objecttype_prompt.txt"
)

VALID_OBJECT_TYPES = {
    "Column",
    "Instance",
    "SQL_INLINE_TABLE_VALUED_FUNCTION",
    "SQL_SCALAR_FUNCTION",
    "SQL_STORED_PROCEDURE",
    "SQL_TABLE_VALUED_FUNCTION",
    "Table",
    "VIEW",
    "LLM_PROMPT",
}

OBJECT_TYPE_FILTER_PROMPT = """
You are classifying a user question for a Qdrant vector search over SQL Server database metadata and related GitHub tutorial prompts.

User question:
{user_prompt}

Available ObjectType payload values:
- Column: SQL Server table or view column.
- Instance: instance of an entity, usually a table row with a unique key.
- SQL_INLINE_TABLE_VALUED_FUNCTION: SQL Server inline table-valued function.
- SQL_SCALAR_FUNCTION: SQL Server scalar function.
- SQL_STORED_PROCEDURE: SQL Server stored procedure.
- SQL_TABLE_VALUED_FUNCTION: SQL Server multi-statement table-valued function.
- Table: SQL Server database table.
- VIEW: SQL Server view, reusable SELECT logic.
- LLM_PROMPT: tutorial or GitHub prompt explaining a concept.
- ALL: use only when every ObjectType is genuinely useful.

Return only either:
1. a comma-separated list of ObjectType values, or
2. ALL if every ObjectType is truly needed.

No explanation. No markdown.

Choose ObjectTypes that are likely to directly contain the answer. Be inclusive, but do not return every ObjectType unless the question truly requires every category.

Examples:
User question: where are Markov models stored
Return: Table,Column,LLM_PROMPT

User question: how are Markov models created
Return: SQL_STORED_PROCEDURE,SQL_TABLE_VALUED_FUNCTION,SQL_INLINE_TABLE_VALUED_FUNCTION,LLM_PROMPT

User question: what are the columns of ModelEvents
Return: Column,Table

User question: search everything related to Markov models
Return: ALL
"""

class TaskContext:
    def __init__(
        self,
        user_prompt: str,
        *,
        prompt_is_sql: bool = False,
        use_llm: bool = True,
        use_objecttype_filter: bool = False,
        results_limit: int = RESULTS_LIMIT,
        on_hits_retrieved=None,
    ):
        self.user_prompt = user_prompt
        self.prompt_is_sql = prompt_is_sql
        self.use_llm = use_llm
        self.use_objecttype_filter = use_objecttype_filter
        self.results_limit = results_limit
        self.on_hits_retrieved = on_hits_retrieved

        self.goal = None
        self.process: list[str] = []
        self.current_step = None
        self.retrieved_hits = []
        self.retrieved_context = ""
        self.link_contents = []
        self.metadata_findings = []
        self.sql_attempts: list[str] = []
        self.sql_results: list[pd.DataFrame] = []
        self.errors: list[str] = []
        self.final_answer: str | None = None
        self.final_dataframe: pd.DataFrame | None = None
        self.status = "Ready."



class BaseAgent:
    def __init__(self, name):
    
        self.name = name
        self.user_prompt:str=None
        self.call_log: list["AgentCall"] = []

    def run(self, context):
        raise NotImplementedError("Subclasses must implement the run() method.")
    
    def ask_llm_raw(self, prompt: str) -> str:
        if llm == "openai":
            response = openai.ChatCompletion.create(
                model=CHATGPT_MODEL,
                messages=[
                    {"role": "user", "content": prompt},
                ],
                max_tokens=80,
            )
            return response["choices"][0]["message"]["content"].strip()

        elif llm == "ollama":
            response = OLLAMA_CLIENT.chat(
                model=OLLAMA_CHAT_MODEL,
                messages=[
                    {"role": "user", "content": prompt},
                ],
                options={"num_ctx": ctx}
            )
            message = response.get("message", {})
            return message.get("content", "").strip()

        else:
            raise ValueError(f"Unsupported llm: {llm}")
    
    def embed_text(self,text: str) -> list[float]:

        def _clean_for_embedding(text: str) -> str:
            """
            Clean text before sending to an embedding model.
            Removes brackets and noisy punctuation while preserving meaning.
            Expands SQL/CamelCase identifiers for better embeddings.
            """
            if not text:
                return ""

            text = str(text)

            # 1. Replace common problematic characters with space
            text = text.replace("[", "").replace("]", "")
            text = text.replace("{", "").replace("}", "")
            text = text.replace("(", "").replace(")", "")

            # 2. Replace SQL/schema separators and identifier separators
            text = text.replace("dbo.", "")
            text = re.sub(r"[_\-]+", " ", text)

            # 3. Split camelCase / PascalCase:
            # EventPropertiesParsed -> Event Properties Parsed
            text = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", text)

            # 4. Split acronym followed by word:
            # JSONPropertyValue -> JSON Property Value
            text = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", " ", text)

            # 5. Normalize whitespace
            text = re.sub(r"\s+", " ", text).strip()

            return text
          
        response = OLLAMA_CLIENT.embed(model=OLLAMA_EMBED_MODEL, input=_clean_for_embedding(text))

        embeddings = response.get("embeddings")
        if not embeddings or not embeddings[0]:
            raise ValueError("Ollama returned no embedding.")

        return embeddings[0]
    
    def ask_llm(self, call) -> str:
        self.call_log.append(call)

        chat_model = CHATGPT_MODEL if llm == "openai" else OLLAMA_CHAT_MODEL
        print(f"Calling {llm} chat with model: {chat_model}")

        print(f"Prompt Length:\n{len(call.prompt)}\n")
        print(f"Context length: {len(call.context)}")

        self.user_prompt = prompt_template.replace("{prompt}", call.prompt).replace("{context}", call.context)


        if llm == "openai":
            response = openai.ChatCompletion.create(
                model=CHATGPT_MODEL,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": self.user_prompt},
                ],
                max_tokens=MAX_TOKENS,
            )
            response_message = response["choices"][0]["message"]["content"].strip()

        elif llm == "ollama":
            response = OLLAMA_CLIENT.chat(
                model=OLLAMA_CHAT_MODEL,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": self.user_prompt},
                ],
                options={"num_ctx": ctx}
            )
            message = response.get("message", {})
            response_message = message.get("content", "").strip()

        else:
            raise ValueError(f"Unsupported llm: {llm}")

        call.response = response_message
        call.end_timestamp = pd.Timestamp.now()
        return response_message
    
class AgentCall:
    def __init__(self, calling_agent: BaseAgent, prompt:str, context: str):
        self.calling_agent = calling_agent
        self.prompt = prompt
        self.context = context
        self.start_timestamp = pd.Timestamp.now()
        self.response = None
        self.end_timestamp = None


class GuidanceAgent(BaseAgent):

    def run(self, context: TaskContext):
        object_names = []
        for hit in context.retrieved_hits[:8]:
            payload = getattr(hit, "payload", {}) or {}
            obj_name = payload.get("ObjectName")
            if obj_name:
                object_names.append(obj_name)

        process_hint = ""
        if object_names:
            process_hint = "\nRelevant object names already found:\n- " + "\n- ".join(object_names)

        guidance_prompt = (
            "The user wants help with Time Molecules / TimeSolution. "
            "Explain the process for accomplishing the request. "
            "If SQL might be needed later, explain the process first and include relevant object names. "
            "Do not fabricate objects."
            f"{process_hint}"
        )
        context.current_step = "guidance"
        context.final_answer = self.ask_llm(
            AgentCall(self, guidance_prompt + "\n\nUser request:\n" + context.user_prompt, context.retrieved_context)
        )
        return context
        return context

class DiscoveryAgent(BaseAgent):
    def run(self, context: TaskContext):
        findings = []
        for hit in context.retrieved_hits:
            payload = getattr(hit, "payload", {}) or {}
            object_name = payload.get("ObjectName")
            object_type = payload.get("ObjectType")
            description = payload.get("Description")
            utilization = payload.get("Utilization")
            if object_name or object_type:
                findings.append({
                    "ObjectName": object_name,
                    "ObjectType": object_type,
                    "Description": description,
                    "Utilization": utilization,
                })
        context.metadata_findings = findings
        return context

class SQLAgent(BaseAgent):

    def __init__(self, name):
        super().__init__(name)


        def _build_connection_string() -> str:

            return (
                f"DRIVER={{{CONN_DRIVER}}};"
                f"SERVER={SERVER};"
                f"DATABASE={DATABASE};"
                "Trusted_Connection=yes;"
                "Encrypt=yes;"
                "TrustServerCertificate=yes;"
            )

        self.conn_str = _build_connection_string()

    def run(self, sql: str):
        try:
            with pyodbc.connect(self.conn_str, timeout=30) as conn:
                return pd.read_sql(sql, conn)
        except Exception as e:
            print(f"⚠️ SQL query failed: {e}")
            raise

class PrimaryAgent(BaseAgent):
    def __init__(self, name, guidance_agent, discovery_agent, sql_agent):
        super().__init__(name)
        self.guidance_agent = guidance_agent
        self.discovery_agent = discovery_agent
        self.sql_agent = sql_agent

    def _extract_sql(self, text: str) -> str | None:
        import re
        if not text:
            return None
        match = re.search(r"```sql\s*(.*?)\s*```", text, re.DOTALL | re.IGNORECASE)
        if match:
            return match.group(1).strip()
        stripped = text.strip()
        if stripped.upper().startswith(("SELECT", "WITH", "EXEC", "DECLARE")):
            return stripped
        return None
    
    def classify_object_type_filter(self, prompt: str) -> list[str] | None:
  
        classifier_prompt = filter_objecttype_prompt.replace("{USER_PROMPT}", prompt)
        response = self.ask_llm_raw(classifier_prompt)

        cleaned = (response or "").strip()

        if cleaned.upper() == "ALL":
            return None

        values = [
            value.strip()
            for value in cleaned.replace("\n", ",").split(",")
            if value.strip()
        ]

        object_types = [
            value
            for value in values
            if value in VALID_OBJECT_TYPES
        ]
        print(f"✅ LLM classified ObjectType filter values: {object_types if object_types else 'ALL'}")
        return object_types or None


    def build_qdrant_object_type_filter(self, object_types: list[str] | None):
        if not object_types:
            return None

        return Filter(
            must=[
                FieldCondition(
                    key="ObjectType",
                    match=MatchAny(any=object_types),
                )
            ]
        )

    def run(self, context: TaskContext):
        context.status = "Checking Qdrant collection..."
        ensure_collection_exists()

        context.status = "Embedding prompt and searching Qdrant..."

        hits = self.search_metadata(
            context.user_prompt,
            limit=context.results_limit,
            use_objecttype_filter=context.use_objecttype_filter,
        )

        context.retrieved_hits = hits
        context.retrieved_context = build_context_from_hits(hits)
        self.discovery_agent.run(context)

        if context.on_hits_retrieved:
            context.on_hits_retrieved(context.retrieved_hits)

        if context.prompt_is_sql:
            context.current_step = "execute_sql"
            sql = context.user_prompt.lstrip("\ufeff").replace("\x00", "").strip()
            context.sql_attempts.append(sql)
            context.status = "Executing SQL query..."
            try:
                df = self.sql_agent.run(sql)
                context.final_dataframe = df
                context.sql_results.append(df)
                context.final_answer = "Prompt treated as SQL and executed directly."
                context.status = "Done (SQL executed)."
            except Exception as e:
                context.errors.append(str(e))
                context.final_answer = f"SQL execution failed:\n{e}\n\nSQL was:\n{sql}"
                context.status = f"Error: {e}"
            return context

        if not context.use_llm:
            context.final_answer = "Retrieved hits shown above. LLM summarization is turned off."
            context.status = "Done."
            return context

        context = self.guidance_agent.run(context)

        sql = self._extract_sql(context.final_answer or "")
        if sql:
            context.current_step = "execute_sql"
            context.sql_attempts.append(sql)
            context.status = "Executing SQL query..."
            try:
                df = self.sql_agent.run(sql)
                context.final_dataframe = df
                context.sql_results.append(df)
                context.status = "Done (SQL executed)."
            except Exception as e:
                context.errors.append(str(e))
                context.status = f"Error: {e}"
                context.final_answer = (context.final_answer or "") + f"\n\nSQL execution failed:\n{e}"
        else:
            context.status = "Done."

        return context

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

    def search_metadata(
        self,
        prompt: str,
        limit: int = RESULTS_LIMIT,
        use_objecttype_filter: bool = False,
    ):
        client = get_qdrant_client()
        try:

            if use_objecttype_filter:
                object_types = self.classify_object_type_filter(prompt)
                qdrant_filter = self.build_qdrant_object_type_filter(object_types)
                print(f"Qdrant ObjectType filter: {object_types if object_types else 'ALL'}")
            else:
                object_types = None
                qdrant_filter = None
                print("Qdrant ObjectType filter: BYPASSED")

            query_vector = self.embed_text(prompt)

            results = client.query_points(
                collection_name=COLLECTION_NAME,
                query=query_vector,
                query_filter=qdrant_filter,
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
filter_objecttype_prompt = load_prompt(FILTER_OBJECTTYPE_PROMPT_URL)





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
            guidance_agent=GuidanceAgent("GuidanceAgent"),
            discovery_agent=DiscoveryAgent("DiscoveryAgent"),
            sql_agent=SQLAgent("SQLAgent")
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

        self.use_objecttype_filter_var = BooleanVar(value=False)
        self.use_objecttype_filter_checkbox = Checkbutton(
            button_frame,
            text="Filter ObjectTypes first",
            variable=self.use_objecttype_filter_var,
        )
        self.use_objecttype_filter_checkbox.pack(side=LEFT, padx=(12, 0))

        self.prompt_is_sql_var = BooleanVar(value=False)
        self.prompt_is_sql_checkbox = Checkbutton(
            button_frame,
            text="Prompt is SQL",
            variable=self.prompt_is_sql_var,
        )
        self.prompt_is_sql_checkbox.pack(side=LEFT, padx=(12, 0))

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
        self.results_notebook.select(self.table_frame)
        self.table.show()

        self.results_notebook.select(self.table_frame)   # switch to table tab
        self.table.redraw()
        self.table_frame.update_idletasks()
        self.root.update_idletasks()

    def on_ask(self):
        prompt = self.prompt_box.get("1.0", END).strip()
        if not prompt:
            self.set_status("Enter a prompt first.")
            return

        try:
            results_limit = max(1, int(self.results_limit_var.get()))
        except Exception:
            results_limit = RESULTS_LIMIT

        def _clean_dataframe_for_display(df: pd.DataFrame) -> pd.DataFrame:
            if df is None:
                return df

            def clean_value(value):
                if isinstance(value, (bytes, bytearray)):
                    for enc in ("utf-16", "utf-8", "latin1"):
                        try:
                            return value.decode(enc, errors="replace")
                        except Exception:
                            pass
                    return repr(value)
                return value

            return df.map(clean_value)

        def worker():
            try:
                self.root.after(0, lambda: self.ask_button.config(state="disabled"))
                self.root.after(0, self.start_spinner)
                self.root.after(0, lambda: self.answer_box.delete("1.0", END))
                self.root.after(0, lambda: self.hits_box.delete("1.0", END))

                def clear_table():
                    for widget in self.table_frame.winfo_children():
                        widget.destroy()

                self.root.after(0, clear_table)

                def show_hits_immediately(hits):
                    hits_text = self.primeagent.format_hits_for_display(hits)

                    def update_hits_box():
                        self.hits_box.delete("1.0", END)
                        self.hits_box.insert("1.0", hits_text)
                        self.set_status("Qdrant results retrieved. Waiting for LLM...")

                    self.root.after(0, update_hits_box)

                task = TaskContext(
                    prompt,
                    prompt_is_sql=self.prompt_is_sql_var.get(),
                    use_llm=self.use_llm_var.get(),
                    use_objecttype_filter=self.use_objecttype_filter_var.get(),
                    results_limit=results_limit,
                    on_hits_retrieved=show_hits_immediately,
                )

                result = self.primeagent.run(task)

                if result.final_dataframe is not None:
                    df = _clean_dataframe_for_display(result.final_dataframe)
                    self.root.after(0, lambda: self.show_dataframe(df))

                self.root.after(0, lambda: self.show_text(result.final_answer or "No answer returned."))
                self.root.after(0, lambda: self.set_status(result.status))

            except Exception as e:
                err = str(e)
                self.root.after(0, lambda: self.show_text(f"Error:\n{err}"))
                self.root.after(0, lambda: self.set_status(f"Error: {err}"))

            finally:
                self.root.after(0, lambda: self.ask_button.config(state="normal"))
                self.root.after(0, self.stop_spinner)

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
