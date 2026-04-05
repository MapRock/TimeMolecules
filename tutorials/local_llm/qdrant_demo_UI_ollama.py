from qdrant_client import QdrantClient

import json
import os
import threading
from pathlib import Path
from tkinter import Tk, Label, Button, END, BOTH, X, Frame, LEFT, BooleanVar, Checkbutton, Spinbox, IntVar
from tkinter.scrolledtext import ScrolledText

import ollama
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
COLLECTION_NAME = os.getenv("QDRANT_COLLECTION_NAME", "time_molecules_directory")
QDRANT_PATH = os.getenv("QDRANT_PATH", "c:/MapRock/TimeMolecules/qdrant_data_ollama")

OLLAMA_HOST = os.getenv("OLLAMA_HOST", None)
OLLAMA_EMBED_MODEL = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")
OLLAMA_CHAT_MODEL = os.getenv("OLLAMA_CHAT_MODEL", "llama3.2")
RESULTS_LIMIT = int(os.getenv("RESULTS_LIMIT", "5"))


# ----------------------------
# Ollama helpers
# ----------------------------
def get_ollama_client():
    if OLLAMA_HOST:
        return ollama.Client(host=OLLAMA_HOST)
    return ollama.Client()


OLLAMA_CLIENT = get_ollama_client()


def embed_text(text: str) -> list[float]:
    response = OLLAMA_CLIENT.embed(model=OLLAMA_EMBED_MODEL, input=text)

    embeddings = response.get("embeddings")
    if not embeddings or not embeddings[0]:
        raise ValueError("Ollama returned no embedding.")

    return embeddings[0]


def ask_ollama(prompt: str, context: str) -> str:
    system_prompt = (
        "You are assisting with Time Molecules / TimeSolution metadata. "
        "Answer from the retrieved Qdrant context when possible. "
        "If the context is incomplete, say what is uncertain. "
        "Be concrete and developer-oriented."
    )

    print(f"Calling Ollama chat with model: {OLLAMA_CHAT_MODEL}")
    print(f"Prompt Length:\n{len(prompt)}\n")
    print(f"Context length: {len(context)}")

    user_prompt = f"""
Retrieved context:
{context}

User question:
{prompt}

Instructions:
- Base the answer primarily on the retrieved context.
- Mention object names when relevant.
- Distinguish clearly between compute, storage, update, TVF, function, procedure, and view responsibilities.
- If the retrieved context is weak or ambiguous, say so.

If the prompt is a 'how to' question, favor types that are SQL_STORED_PROCEDURE, SQL_TABLE_VALUED_FUNCTION, SQL_INLINE_TABLE_VALUED_FUNCTION, SQL_SCALAR_FUNCTION.
"""

    response = OLLAMA_CLIENT.chat(
        model=OLLAMA_CHAT_MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
    )

    message = response.get("message", {})
    return message.get("content", "").strip()


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


def search_metadata(prompt: str, limit: int = RESULTS_LIMIT):
    client = get_qdrant_client()
    try:
        query_vector = embed_text(prompt)
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
# Prompt grounding
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
    parts = []

    for i, hit in enumerate(hits, start=1):
        payload = hit.payload or {}
        object_name = payload.get("ObjectName", "")
        object_type = payload.get("ObjectType", "")
        description = payload.get("Description", "")
        utilization = payload.get("Utilization", "")
        block = f"""
Match {i}
Score: {getattr(hit, "score", "")}
Object Name: {object_name}
Object Type: {object_type}
Description: {description}
Utilization: {utilization}
""".strip()

        parts.append(block)

    return "\n\n" + ("\n\n" + ("-" * 70) + "\n\n").join(parts)


def format_hits_for_display(hits) -> str:
    if not hits:
        return "No matches found."

    lines = []
    for i, hit in enumerate(hits, start=1):
        payload = hit.payload or {}
        lines.append(f"{i}. {payload.get('ObjectName', '<unknown>')} [{payload.get('ObjectType', '')}]")
        lines.append(f"   Score: {round(getattr(hit, 'score', 0), 4)}")

        description = payload.get("Description")
        if description:
            lines.append(f"   Description: {description}")

        utilization = payload.get("Utilization")
        if utilization:
            lines.append(f"   Utilization: {utilization}")

        lines.append("")

    return "\n".join(lines).strip()


# ----------------------------
# UI
# ----------------------------
class TimeMoleculesUI:
    def __init__(self, root: Tk):
        self.root = root
        self.root.title("Time Molecules Prompt UI (Query Qdrant + Ollama)")
        self.root.geometry("1100x820")

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
            button_frame,
            from_=1,
            to=50,
            width=4,
            textvariable=self.results_limit_var
        )
        self.results_limit_spin.pack(side=LEFT, padx=(0, 12))

        self.use_llm_var = BooleanVar(value=True)
        self.use_llm_checkbox = Checkbutton(
            button_frame,
            text="Use Ollama to summarize retrieved hits",
            variable=self.use_llm_var,
        )
        self.use_llm_checkbox.pack(side=LEFT)

        self.status_label = Label(root, text="Ready.", anchor="w", justify="left")
        self.status_label.pack(fill=X, padx=10, pady=5)

        hits_label = Label(root, text="Retrieved Objects:")
        hits_label.pack(anchor="w", padx=10)

        self.hits_box = ScrolledText(root, height=14, wrap="word")
        self.hits_box.pack(fill=BOTH, expand=False, padx=10, pady=5)

        answer_label = Label(root, text="Answer:")
        answer_label.pack(anchor="w", padx=10)

        self.answer_box = ScrolledText(root, height=20, wrap="word")
        self.answer_box.pack(fill=BOTH, expand=True, padx=10, pady=5)

    def set_status(self, text: str):
        self.status_label.config(text=text)
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

        def worker():
            try:
                self.ask_button.config(state="disabled")
                self.answer_box.delete("1.0", END)
                self.hits_box.delete("1.0", END)

                self.set_status("Checking Qdrant collection...")
                ensure_collection_exists()

                self.set_status("Embedding prompt and searching Qdrant...")
                hits = search_metadata(prompt, limit=results_limit)

                self.hits_box.insert("1.0", format_hits_for_display(hits))

                if not self.use_llm_var.get():
                    self.answer_box.insert(
                        "1.0",
                        "Retrieved hits shown above. Ollama summarization is turned off."
                    )
                    self.set_status("Done.")
                    return

                context = build_context_from_hits(hits)

                self.set_status("Calling Ollama on retrieved hits...")
                answer = ask_ollama(prompt, context)

                self.answer_box.insert("1.0", answer)
                self.set_status("Done.")

            except Exception as e:
                self.answer_box.insert("1.0", f"Error:\n{e}")
                self.set_status(f"Error: {e}")
            finally:
                self.ask_button.config(state="normal")

        threading.Thread(target=worker, daemon=True).start()


# ----------------------------
# Main
# ----------------------------
def validate_config():
    if not QDRANT_PATH:
        raise RuntimeError("QDRANT_PATH is not set.")
    if not COLLECTION_NAME:
        raise RuntimeError("QDRANT_COLLECTION_NAME is not set.")


if __name__ == "__main__":
    validate_config()

    root = Tk()
    app = TimeMoleculesUI(root)
    root.mainloop()