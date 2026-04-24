"""
TimeMolecules AI Agent Demo / Index Builder
Part of tutorials/ai_agent_skills

- build_qdrant_index.py   → creates/updates the Qdrant collection from TimeSolution metadata + llm_prompts
- time_molecules_agent_demo.py → Tkinter GUI for semantic search + LLM-grounded answers

Run build_qdrant_index.py first, then the demo.
Uses .env + local Qdrant folder.
"""
from pickle import GLOBAL
import re
import csv
import json
import os
import threading
from datetime import datetime
from pathlib import Path
from tkinter import Tk, Label, Button, END, BOTH, X, Frame, LEFT, BooleanVar, Checkbutton, Spinbox, IntVar, StringVar
from tkinter.scrolledtext import ScrolledText
from tkinter import ttk

import pandas as pd
import pyodbc
import requests
from pandastable import Table
from qdrant_client import QdrantClient
from qdrant_client.models import Filter, FieldCondition, MatchAny

from shared_llm import load_env_upward, read_llm_config, SharedLLM
import write_to_import_events as imp

load_env_upward(__file__)

LLM_CONFIG = read_llm_config()
SHARED_LLM = SharedLLM(LLM_CONFIG)

llm = LLM_CONFIG.chat_llm
EMBED_LLM = LLM_CONFIG.embed_llm
EMBED_MODEL = LLM_CONFIG.embed_model
QDRANT_PATH = LLM_CONFIG.qdrant_path
COLLECTION_NAME = LLM_CONFIG.collection_name
MAX_TOKENS = LLM_CONFIG.max_tokens
ctx = LLM_CONFIG.ollama_ctx

RESULTS_LIMIT = int(os.getenv("RESULTS_LIMIT", "5"))
DEFAULT_OUTPUT_DIR = os.getenv("DEFAULT_OUTPUT_DIR", str(Path(__file__).resolve().parent / "output"))

SERVER = os.getenv("TIMESOLUTION_SERVER_NAME")
DATABASE = os.getenv("TIMESOLUTION_DATABASE_NAME")
CONN_DRIVER = os.getenv("TIMESOLUTION_CONNECTION_DRIVER", "ODBC Driver 18 for SQL Server")

case_id = ""


# For logging AI agent workflow stages to TimeSolution's STAGE.ImportEvents
workflow_name = "AI Agent Task"
ai_agent_source_id = 13  # Replace with actual SourceID for the agent in dbo.Sources in TimeSolution
access_bitmap = 7  # access bitmap for the event; adjust as needed based on your TimeSolution configuration

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

CONTEXT_PROMPT_URL = (
    "https://raw.githubusercontent.com/MapRock/TimeMolecules/main/"
    "tutorials/ai_agent_skills/context_prompt.txt"
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
        self.app_context_summary = ""




class BaseAgent:
    def __init__(self, name):
    
        self.name = name
        self.user_prompt:str=None
        self.call_log: list["AgentCall"] = [] # List of AgentCall instances for logging calls to LLM and SQL execution

    def run(self, context):
        raise NotImplementedError("Subclasses must implement the run() method.")
    
    def ask_llm_raw(self, prompt: str) -> str:
        return SHARED_LLM.chat_once(
            [{"role": "user", "content": prompt}],
            max_tokens=80,
        )
    
    def embed_text(self, text: str) -> list[float]:
        return SHARED_LLM.embed_text(text)
    
    def ask_llm(self, call) -> str:
        self.call_log.append(call)

        print(f"Calling {llm} chat with model: {LLM_CONFIG.chat_model}")
        print(f"Prompt Length:\n{len(call.prompt)}\n")
        print(f"Context length: {len(call.context)}")

        self.user_prompt = prompt_template.replace("{prompt}", call.prompt).replace("{context}", call.context)

        response_message = SHARED_LLM.chat_once(
            [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": self.user_prompt},
            ],
            max_tokens=MAX_TOKENS,
        )

        call.response = response_message
        call.end_timestamp = pd.Timestamp.now()
        return response_message
class AgentCall:
    def __init__(self, calling_agent: BaseAgent, natural_key:str, event:str, prompt:str, context: str):
        self.calling_agent = calling_agent
        self.prompt = prompt
        self.context = context
        self.start_timestamp = pd.Timestamp.now()
        self.response = None
        self.end_timestamp = None
        self.log_sql_execution(
            agent_name=calling_agent.name,     
            natural_key=natural_key,     
            phase=event, 
            extra_properties={"agent_name": calling_agent.name} 
        )
        

    def log_sql_execution(self, agent_name: str, natural_key: str, phase: str, extra_properties: dict | None = None):
        """
        Logs the start or end of a SQL execution workflow to STAGE.ImportEvents in TimeSolution,
        or falls back to CSV through write_to_import_events.py.
        """
        cnxn = None

        if TIMESOLUTION_AVAILABLE:
            try:
                cnxn = SQLAgent.get_cnxn()
            except Exception:
                cnxn = None

        imp.log_ai_agent_stage_event(
            cnxn,
            agent_name=agent_name,
            natural_key=natural_key,
            phase=phase,
            source_id=ai_agent_source_id,
            workflow_name=workflow_name,
            access_bitmap=access_bitmap,
            extra_actual_properties=extra_properties,
        )


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

        if context.app_context_summary:
            context.retrieved_context = (
                "Prior workbench context:\n"
                + context.app_context_summary
                + "\n\nRetrieved metadata context:\n"
                + context.retrieved_context
            )
            
        context.current_step = f"Guidance from {llm}"
        context.final_answer = self.ask_llm(
            AgentCall(self, case_id, context.current_step, guidance_prompt + "\n\nUser request:\n" + context.user_prompt, context.retrieved_context)
        )
        return context


class DiscoveryAgent(BaseAgent):
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

    def run(self, context: TaskContext):
        hits = self.search_metadata(
            context.user_prompt,
            limit=context.results_limit,
            use_objecttype_filter=context.use_objecttype_filter,
        )

        context.retrieved_hits = hits
        context.retrieved_context = build_context_from_hits(hits)

        findings = []
        for hit in hits:
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

    @staticmethod
    def get_cnxn():

        def _build_connection_string() -> str:

            return (
                f"DRIVER={{{CONN_DRIVER}}};"
                f"SERVER={SERVER};"
                f"DATABASE={DATABASE};"
                "Trusted_Connection=yes;"
                "Encrypt=yes;"
                "TrustServerCertificate=yes;"
            )

        conn_str = _build_connection_string()
        try:
            return pyodbc.connect(conn_str, timeout=30) 
        except Exception as e:
            print(f"⚠️ Obtaining SQL connection failed: {e}")
            raise

    @staticmethod
    def normalize_sql(sql: str) -> str:
        return (sql or "").lstrip("\ufeff").replace("\x00", "").strip()

    def run(self, sql: str):
        sql = self.normalize_sql(sql)
        try:
            with SQLAgent.get_cnxn() as conn:
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
    



    def run(self, context: TaskContext):

        def _change_context_status(new_status: str):
            context.status = new_status
            # Log that PrimaryAgent was asked something
            AgentCall(
                self,
                case_id,
                new_status,
                context.user_prompt,
                ""
            )

        _change_context_status("Checking Qdrant collection...")
        ensure_collection_exists()

        _change_context_status("Embedding prompt and searching Qdrant")

        context = self.discovery_agent.run(context)

        if context.on_hits_retrieved:
            context.on_hits_retrieved(context.retrieved_hits)

        if context.prompt_is_sql:
            context.current_step = "execute_sql"
            sql = self.sql_agent.normalize_sql(context.user_prompt)
            context.sql_attempts.append(sql)
            _change_context_status("Execute SQL query")
            try:
                df = self.sql_agent.run(sql)
                context.final_dataframe = df
                context.sql_results.append(df)
                context.final_answer = "Prompt treated as SQL and executed directly."
                _change_context_status("Done (SQL executed).")
            except Exception as e:
                context.errors.append(str(e))
                context.final_answer = f"SQL execution failed:\n{e}\n\nSQL was:\n{sql}"
                _change_context_status(f"Error: {e}")
            return context

        if not context.use_llm:
            context.final_answer = "Retrieved hits shown above. LLM summarization is turned off."
            _change_context_status("Done.")
            return context

        context = self.guidance_agent.run(context)

        sql = self._extract_sql(context.final_answer or "")
        if sql:
            context.current_step = "execute_sql"
            sql = self.sql_agent.normalize_sql(sql)
            context.sql_attempts.append(sql)
            _change_context_status("Execute SQL query")
            try:
                df = self.sql_agent.run(sql)
                context.final_dataframe = df
                context.sql_results.append(df)
                _change_context_status("Done (SQL executed).")
            except Exception as e:
                context.errors.append(str(e))
                _change_context_status(f"Error: {e}")
                context.final_answer = (context.final_answer or "") + f"\n\nSQL execution failed:\n{e}"
        else:
            _change_context_status("Done.")

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
    
def get_openai_message_text(response) -> str:
    if not response or not response.choices:
        return ""
    message = response.choices[0].message
    return (message.content or "").strip()


# Gitub URL helper to convert GitHub URLs to raw content URLs when possible, especially for folders (pointing to README.md)
def trusted_link_to_fetchable_url(url: str) -> str:
    """
    Only allow trusted domains for LLM-prompt-style links.
    - GitHub MapRock folder URLs -> raw README.md
    - GitHub MapRock blob URLs   -> raw file content
    - eugeneasahara.com URLs     -> fetch as-is
    """
    if not url:
        return url

    url = url.strip().rstrip("/")

    if not is_allowed_link_url(url):
        return ""

    if url.startswith("https://github.com/MapRock/"):
        if "/tree/" in url:
            return (
                url.replace("https://github.com/", "https://raw.githubusercontent.com/")
                   .replace("/tree/", "/")
                + "/readme.md"
            )

        if "/blob/" in url:
            return (
                url.replace("https://github.com/", "https://raw.githubusercontent.com/")
                   .replace("/blob/", "/")
            )

    if url.startswith("https://eugeneasahara.com/"):
        return url

    return ""

def is_allowed_link_url(url: str) -> bool:
    if not url:
        return False

    url = url.strip()

    allowed_prefixes = (
        "https://github.com/MapRock/",
        "https://eugeneasahara.com/",
    )

    return any(url.startswith(prefix) for prefix in allowed_prefixes)



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
context_prompt = load_prompt(CONTEXT_PROMPT_URL)





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


        self.current_hits = []
        self.selected_hit = None
        self.selected_urls = []
        self.selected_url_var = StringVar()
        self.context_summary = ""

        top = Frame(root)
        top.pack(fill=X, padx=10, pady=10)

        self.mode_label = Label(
            top,
        text=(
            f"Qdrant collection: {COLLECTION_NAME} | "
            f"Chat backend: {llm} | "
            f"Embed backend: {EMBED_LLM}"
        ),
            anchor="w",
            justify="left",
        )
        self.mode_label.pack(fill=X)

        prompt_label = Label(root, text="Prompt:")
        prompt_label.pack(anchor="w", padx=10)

        self.prompt_box = ScrolledText(root, height=5, wrap="word")
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

        progress_frame = Frame(root)
        progress_frame.pack(fill=X, padx=10, pady=(0, 8))

        self.spinner = ttk.Progressbar(progress_frame, mode="indeterminate", length=220)
        self.spinner.pack(side=LEFT, padx=(0, 12))

        Label(progress_frame, text="Context chars:").pack(side=LEFT, padx=(0, 4))

        self.context_char_limit_var = IntVar(value=10000)
        self.context_char_limit_spin = Spinbox(
            progress_frame,
            from_=0,
            to=50000,
            increment=1000,
            width=7,
            textvariable=self.context_char_limit_var,
        )
        self.context_char_limit_spin.pack(side=LEFT, padx=(0, 8))

        self.clear_context_button = Button(
            progress_frame,
            text="Clear context",
            command=self.on_clear_context,
        )
        self.clear_context_button.pack(side=LEFT)

        hits_label = Label(root, text="Retrieved Objects:")
        hits_label.pack(anchor="w", padx=10)

        self.hits_tree = ttk.Treeview(
            root,
            columns=("rank", "object_name", "object_type", "score"),
            show="headings",
            height=5
        )
        self.hits_tree.heading("rank", text="#")
        self.hits_tree.heading("object_name", text="Object Name")
        self.hits_tree.heading("object_type", text="Object Type")
        self.hits_tree.heading("score", text="Score")

        self.hits_tree.column("rank", width=40, anchor="center")
        self.hits_tree.column("object_name", width=360, anchor="w")
        self.hits_tree.column("object_type", width=220, anchor="w")
        self.hits_tree.column("score", width=80, anchor="center")

        self.hits_tree.pack(fill=X, padx=10, pady=(5, 2))
        self.hits_tree.bind("<<TreeviewSelect>>", self.on_hit_selected)

        self.hits_box = ScrolledText(root, height=5, wrap="word")

        selected_label = Label(root, text="Selected Item:")
        selected_label.pack(anchor="w", padx=10)

        self.selected_item_box = ScrolledText(root, height=8, wrap="word")
        self.selected_item_box.pack(fill=BOTH, expand=False, padx=10, pady=5)

        actions_frame = Frame(root)
        actions_frame.pack(fill=X, padx=10, pady=5)

        self.load_link_button = Button(
            actions_frame,
            text="Load linked content",
            command=self.on_load_linked_content,
            state="disabled",
        )
        self.load_link_button.pack(side=LEFT, padx=(0, 8))

        self.generate_sql_button = Button(
            actions_frame,
            text="Generate sample SQL",
            command=self.on_generate_sample_sql,
            state="disabled",
        )
        self.generate_sql_button.pack(side=LEFT, padx=(0, 8))

        self.url_label = Label(actions_frame, text="Linked URL:")
        self.url_label.pack(side=LEFT, padx=(8, 4))

        self.url_combo = ttk.Combobox(
            actions_frame,
            textvariable=self.selected_url_var,
            state="disabled",
            width=65,
        )
        self.url_combo.pack(side=LEFT, fill=X, expand=True, padx=(0, 8))

        self.copy_url_button = Button(
            actions_frame,
            text="Copy URL",
            command=self.on_copy_selected_url,
            state="disabled",
        )
        self.copy_url_button.pack(side=LEFT)

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

        self.context_frame = Frame(self.results_notebook)
        self.results_notebook.add(self.context_frame, text="Context")

        self.context_box = ScrolledText(self.context_frame, wrap="word")
        self.context_box.pack(fill=BOTH, expand=True)

    def show_context(self, text: str):
        self.context_box.delete("1.0", END)
        self.context_box.insert("1.0", text or "")

    def on_clear_context(self):
        self.context_summary = ""
        self.show_context("")
        self.set_status("Context cleared.")

    def summarize_hits_for_context(self, hits) -> str:
        if not hits:
            return "(none)"

        lines = []
        for i, hit in enumerate(hits[:10], start=1):
            payload = getattr(hit, "payload", {}) or {}
            lines.append(
                f"{i}. {payload.get('ObjectName', '<unknown>')} "
                f"[{payload.get('ObjectType', '')}] "
                f"score={round(getattr(hit, 'score', 0), 4)}"
            )

        return "\n".join(lines)
    
    def update_context_summary_async(self, prompt: str, result: TaskContext):
        try:
            char_limit = int(self.context_char_limit_var.get())
        except Exception:
            char_limit = 10000

        if char_limit <= 0:
            return

        previous_context = self.context_summary or ""
        hits_summary = self.summarize_hits_for_context(result.retrieved_hits)
        answer = result.final_answer or ""
        sql_attempts = "\n\n".join(result.sql_attempts) if result.sql_attempts else "(none)"
        errors = "\n".join(result.errors) if result.errors else "(none)"

        filled_prompt = (
            context_prompt
            .replace("{char_limit}", str(char_limit))
            .replace("{previous_context}", previous_context)
            .replace("{prompt}", prompt)
            .replace("{hits_summary}", hits_summary)
            .replace("{answer}", answer)
            .replace("{sql_attempts}", sql_attempts)
            .replace("{errors}", errors)
        )

        def context_worker():
            try:
                self.root.after(0, lambda: self.set_status("Rebuilding context summary..."))
                self.root.after(0, self.start_spinner)

                new_context = SHARED_LLM.chat_once(
                    [{"role": "user", "content": filled_prompt}],
                    max_tokens=MAX_TOKENS,
                )

                if len(new_context) > char_limit:
                    new_context = new_context[:char_limit]

                def apply_context():
                    self.context_summary = new_context
                    self.show_context(new_context)
                    self.set_status("Context summary updated.")

                self.root.after(0, apply_context)

            except Exception as e:
                err = str(e)
                self.root.after(0, lambda: self.set_status(f"Context update failed: {err}"))

            finally:
                self.root.after(0, self.stop_spinner)

        threading.Thread(target=context_worker, daemon=True).start()

    def clean_dataframe_for_display(self, df: pd.DataFrame) -> pd.DataFrame:
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
    
    def refresh_selected_urls(self):
        self.selected_urls = self.extract_urls_from_selected_item_text()

        if self.selected_urls:
            self.url_combo["values"] = self.selected_urls
            self.selected_url_var.set(self.selected_urls[0])
            self.url_combo.config(state="readonly")
            self.copy_url_button.config(state="normal")
            self.load_link_button.config(state="normal")
        else:
            self.url_combo["values"] = []
            self.selected_url_var.set("")
            self.url_combo.config(state="disabled")
            self.copy_url_button.config(state="disabled")
            self.load_link_button.config(state="disabled")


    def extract_urls_from_selected_item_text(self) -> list[str]:
        details_text = self.selected_item_box.get("1.0", END)
        if not details_text:
            return []

        matches = re.findall(r"https?://[^\s)\]>\"']+", details_text)

        seen = set()
        urls = []
        for url in matches:
            if url not in seen:
                seen.add(url)
                urls.append(url)

        return urls

    def get_selected_url(self) -> str:
        url = self.selected_url_var.get().strip()
        if url:
            return url
        if self.selected_urls:
            return self.selected_urls[0]
        return ""
    
    def populate_hits_tree(self, hits):
        self.current_hits = list(hits or [])
        self.selected_hit = None

        for item in self.hits_tree.get_children():
            self.hits_tree.delete(item)

        for i, hit in enumerate(self.current_hits, start=1):
            payload = getattr(hit, "payload", {}) or {}
            obj_name = payload.get("ObjectName", "<unknown>")
            obj_type = payload.get("ObjectType", "")
            score = round(getattr(hit, "score", 0), 4)

            self.hits_tree.insert(
                "",
                "end",
                iid=str(i - 1),   # use hit index as row id
                values=(i, obj_name, obj_type, score),
            )

        self.selected_item_box.delete("1.0", END)
        self.selected_urls = []
        self.url_combo["values"] = []
        self.selected_url_var.set("")
        self.url_combo.config(state="disabled")
        self.copy_url_button.config(state="disabled")
        self.load_link_button.config(state="disabled")
        self.generate_sql_button.config(state="disabled")

    def on_hit_selected(self, event=None):
        selection = self.hits_tree.selection()
        if not selection:
            self.selected_hit = None
            self.selected_item_box.delete("1.0", END)
            self.selected_urls = []
            self.url_combo["values"] = []
            self.selected_url_var.set("")
            self.url_combo.config(state="disabled")
            self.copy_url_button.config(state="disabled")
            self.load_link_button.config(state="disabled")
            self.generate_sql_button.config(state="disabled")
            return

        idx = int(selection[0])
        if idx < 0 or idx >= len(self.current_hits):
            return

        self.selected_hit = self.current_hits[idx]
        self.show_selected_hit_details()
        self.update_action_buttons()

    def show_selected_hit_details(self):
        self.selected_item_box.delete("1.0", END)

        if not self.selected_hit:
            return

        payload = getattr(self.selected_hit, "payload", {}) or {}

        lines = []
        lines.append(f"Object Name: {payload.get('ObjectName', '')}")
        lines.append(f"Object Type: {payload.get('ObjectType', '')}")
        lines.append(f"Score: {round(getattr(self.selected_hit, 'score', 0), 4)}")

        if payload.get("Description"):
            lines.append("")
            lines.append("Description:")
            lines.append(str(payload.get("Description")))

        if payload.get("Utilization"):
            lines.append("")
            lines.append("Utilization:")
            lines.append(str(payload.get("Utilization")))

        if payload.get("URL"):
            lines.append("")
            lines.append("URL:")
            lines.append(str(payload.get("URL")))

        if payload.get("ParametersJson"):
            lines.append("")
            lines.append("Parameters:")
            lines.append(safe_json_pretty(payload.get("ParametersJson")))

        sample_code = (payload.get("SampleCode") or "").strip()
        if sample_code:
            lines.append("")
            lines.append("SampleCode:")
            lines.append(sample_code)

        self.selected_item_box.insert("1.0", "\n".join(lines))
        self.refresh_selected_urls()

    def update_action_buttons(self):
        if not self.selected_hit:
            self.load_link_button.config(state="disabled")
            self.copy_url_button.config(state="disabled")
            self.url_combo.config(state="disabled")
            self.generate_sql_button.config(state="disabled")
            return

        payload = getattr(self.selected_hit, "payload", {}) or {}
        obj_type = payload.get("ObjectType", "")

        has_url = bool(self.selected_urls)
        is_table_like = obj_type in {"Table", "Column"}

        self.load_link_button.config(state="normal" if has_url else "disabled")
        self.copy_url_button.config(state="normal" if has_url else "disabled")
        self.url_combo.config(state="readonly" if has_url else "disabled")
        self.generate_sql_button.config(state="normal" if is_table_like else "disabled")

    def on_copy_selected_url(self):
        url = self.get_selected_url()
        if not url:
            self.set_status("No URL available to copy.")
            return

        self.root.clipboard_clear()
        self.root.clipboard_append(url)
        self.root.update()
        self.set_status("URL copied to clipboard.")
        

    def on_load_linked_content(self):
        if not self.selected_hit:
            return

        url = self.get_selected_url()

        if not url:
            self.show_text("No URL found for the selected item.")
            return

        fetch_url = trusted_link_to_fetchable_url(url)

        if not fetch_url:
            self.show_text(
                "Blocked link. Only links under https://github.com/MapRock/ "
                "and https://eugeneasahara.com/ are allowed."
            )
            self.set_status("Restricting access to unknown domains.")
            return

        try:
            resp = requests.get(fetch_url, timeout=20)
            resp.raise_for_status()
            text = resp.text

            self.show_text(text)
            self.set_status("Linked content loaded.")
        except Exception as e:
            self.show_text(f"Failed to load linked content:\n{e}")
            self.set_status(f"Error loading link: {e}")

    def on_generate_sample_sql(self):
        if not self.selected_hit:
            return

        payload = getattr(self.selected_hit, "payload", {}) or {}
        obj_name = payload.get("ObjectName", "")
        obj_type = payload.get("ObjectType", "")

        sql = None

        if obj_type == "Table" and obj_name:
            sql = f"SELECT TOP 100 *\nFROM {obj_name}"
        elif obj_type == "Column" and obj_name:
            if "." in obj_name:
                table_name, column_name = obj_name.rsplit(".", 1)
                sql = (
                    f"SELECT TOP 100 {column_name}\n"
                    f"FROM {table_name}\n"
                    f"WHERE {column_name} IS NOT NULL"
                )

        if not sql:
            self.show_text("Could not generate sample SQL for the selected item.")
            return

        self.set_status("Running generated SQL...")

        try:
            df = self.primeagent.sql_agent.run(sql)
            self.show_text(sql)
            df = self.clean_dataframe_for_display(df)
            self.show_dataframe(df)
            self.set_status("Generated SQL executed.")
        except Exception as e:
            self.show_text(str(e))
            self.set_status(f"SQL error: {e}")

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
        # CASE_ID is used for logging and can help correlate events in TimeSolution's STAGE.ImportEvents with specific user interactions in the UI. We set it at the start of on_ask to capture the timestamp of the user's request.
        global case_id
        case_id = "AI Agent Request " + datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
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
                        self.populate_hits_tree(hits)
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

                task.app_context_summary = self.context_summary

                result = self.primeagent.run(task)

                if result.final_dataframe is not None:
                    df = _clean_dataframe_for_display(result.final_dataframe)
                    self.root.after(0, lambda: self.show_dataframe(df))

                self.root.after(0, lambda: self.show_text(result.final_answer or "No answer returned."))
                self.root.after(0, lambda: self.set_status(result.status))
                self.root.after(0, lambda: self.update_context_summary_async(prompt, result))

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
    print(f"✅ QDRANT_PATH: {QDRANT_PATH}")
    print(f"✅ Using LLM for embeddings: {EMBED_LLM}")
    print(f"✅ Chat backend: {llm}")
    print(f"✅ Embed backend: {EMBED_LLM}")
    print(f"✅ Embed model: {EMBED_MODEL}")


    try:
        test_cnxn = SQLAgent.get_cnxn()
        if test_cnxn:
            test_cnxn.close()
        TIMESOLUTION_AVAILABLE = True
    except Exception:
        TIMESOLUTION_AVAILABLE = False
        print("⚠️ TimeSolution unavailable at startup. Stage import logging will fall back to CSV.")


    validate_config()

    root = Tk()
    app = TimeMoleculesUI(root)
    root.mainloop()


