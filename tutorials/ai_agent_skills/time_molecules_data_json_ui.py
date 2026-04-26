"""
Simple Time Molecules static search UI

- Loads precomputed vectors from data.json
- Embeds the user's prompt with Ollama
- Finds top matches by cosine similarity
- Shows payload details
- Opens linked URL in the default browser
- Copies linked URLs to the clipboard
- Loads trusted linked content into a local tab

This version intentionally keeps the static/local design:
- no SQL Server dependency
- no OpenAI dependency
- no pandas dependency
- no requests dependency
- no pandastable dependency
"""

from __future__ import annotations

import json
import math
import os
import re
import threading
import webbrowser
from pathlib import Path
from tkinter import Tk, Frame, Label, Button, END, BOTH, X, LEFT, RIGHT, StringVar
from tkinter import ttk
from tkinter.scrolledtext import ScrolledText
from urllib.request import Request, urlopen

import ollama

DEFAULT_DATA_JSON = os.getenv(
    "TIME_MOLECULES_DATA_JSON",
    str(Path(__file__).resolve().with_name("data.json")),
)
OLLAMA_HOST = os.getenv("OLLAMA_HOST")
OLLAMA_EMBED_MODEL = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")
RESULTS_LIMIT = int(os.getenv("RESULTS_LIMIT", "10"))
EMBEDDINGS_PATH = os.getenv(
    "TIME_MOLECULES_EMBEDDINGS_PATH",
    "C:\\MapRock\\TimeMolecules\\tutorials\\ai_agent_skills\\ai_agent_skills_nomic_embed_text.json",
)


# ----------------------------
# Ollama / embeddings
# ----------------------------
def get_ollama_client():
    if OLLAMA_HOST:
        return ollama.Client(host=OLLAMA_HOST)
    return ollama.Client()


OLLAMA_CLIENT = get_ollama_client()


def clean_for_embedding(text: str) -> str:
    if not text:
        return ""

    text = str(text)
    text = text.replace("[", "").replace("]", "")
    text = text.replace("{", "").replace("}", "")
    text = text.replace("(", "").replace(")", "")
    text = text.replace("dbo.", "")
    text = re.sub(r"[_\-]+", " ", text)
    text = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", text)
    text = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def embed_text(text: str) -> list[float]:
    response = OLLAMA_CLIENT.embed(
        model=OLLAMA_EMBED_MODEL,
        input=clean_for_embedding(text),
    )
    embeddings = response.get("embeddings")
    if not embeddings or not embeddings[0]:
        raise ValueError("Ollama returned no embedding.")
    return embeddings[0]


def cosine_similarity(a: list[float], b: list[float]) -> float:
    if not a or not b or len(a) != len(b):
        return float("-inf")

    dot = 0.0
    norm_a = 0.0
    norm_b = 0.0

    for x, y in zip(a, b):
        dot += x * y
        norm_a += x * x
        norm_b += y * y

    if norm_a == 0.0 or norm_b == 0.0:
        return float("-inf")

    return dot / (math.sqrt(norm_a) * math.sqrt(norm_b))


# ----------------------------
# Static data loading
# ----------------------------
def load_data_json(path: str) -> list[dict]:
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Could not find data.json at: {p}")

    with p.open("r", encoding="utf-8") as f:
        raw = json.load(f)

    records: list[dict] = []
    for item in raw:
        payload = item.get("payload", {}) or {}
        embedding = payload.get("embedding")
        if not embedding:
            continue

        records.append({
            "id": item.get("id"),
            "payload": payload,
            "embedding": embedding,
        })

    if not records:
        raise ValueError("No records with payload.embedding were found in data.json.")

    return records


# ----------------------------
# URL helpers
# ----------------------------
def find_urls_in_payload(payload: dict) -> list[str]:
    urls: list[str] = []

    for key in ("URL", "SourceURL", "GitHubPath"):
        value = payload.get(key)
        if isinstance(value, str) and value.startswith(("http://", "https://")):
            urls.append(value)

    text_fields = [
        payload.get("Description", ""),
        payload.get("Utilization", ""),
        payload.get("ObjectName", ""),
        payload.get("SourceFile", ""),
        payload.get("SampleCode", ""),
        payload.get("ReferencedObjectsJson", ""),
    ]
    joined = "\n".join(str(x) for x in text_fields if x)
    found = re.findall(r"https?://[^\s)\]>\"']+", joined)

    for url in found:
        urls.append(url)

    deduped: list[str] = []
    seen: set[str] = set()
    for url in urls:
        clean_url = url.strip().rstrip(".,;")
        if clean_url and clean_url not in seen:
            seen.add(clean_url)
            deduped.append(clean_url)

    return deduped


def is_allowed_link_url(url: str) -> bool:
    if not url:
        return False

    url = url.strip()

    allowed_prefixes = (
        "https://github.com/MapRock/",
        "https://raw.githubusercontent.com/MapRock/",
        "https://eugeneasahara.com/",
    )

    return any(url.startswith(prefix) for prefix in allowed_prefixes)


def trusted_link_to_fetchable_url(url: str) -> str:
    """
    Only allow trusted links.
    - GitHub MapRock tree URLs -> raw readme.md
    - GitHub MapRock blob URLs -> raw file content
    - raw.githubusercontent.com/MapRock URLs -> fetch as-is
    - eugeneasahara.com URLs -> fetch as-is
    """
    if not url:
        return ""

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

    if url.startswith("https://raw.githubusercontent.com/MapRock/"):
        return url

    if url.startswith("https://eugeneasahara.com/"):
        return url

    return ""


def fetch_url_text(url: str, timeout: int = 20) -> str:
    request = Request(
        url,
        headers={
            "User-Agent": "TimeMoleculesStaticSearch/1.0",
        },
    )
    with urlopen(request, timeout=timeout) as response:
        raw = response.read()
        encoding = response.headers.get_content_charset() or "utf-8"
        return raw.decode(encoding, errors="replace")


def safe_json_pretty(text_value) -> str:
    if not text_value:
        return ""
    try:
        parsed = json.loads(text_value) if isinstance(text_value, str) else text_value
        return json.dumps(parsed, indent=2, ensure_ascii=False)
    except Exception:
        return str(text_value)


# ----------------------------
# UI
# ----------------------------
class StaticSearchUI:
    def __init__(self, root: Tk, records: list[dict]):
        self.root = root
        self.records = records
        self.current_results: list[dict] = []
        self.selected_result: dict | None = None
        self.selected_urls: list[str] = []
        self.selected_url_var = StringVar()

        self.root.title("Time Molecules Static Search")
        self.root.geometry("1100x820")

        top = Frame(root)
        top.pack(fill=X, padx=10, pady=10)

        Label(
            top,
            text=(
                f"Data source: {EMBEDDINGS_PATH} | "
                f"Records: {len(records)} | "
                f"Ollama embed model: {OLLAMA_EMBED_MODEL}"
            ),
            anchor="w",
            justify="left",
        ).pack(fill=X)

        Label(root, text="Prompt:").pack(anchor="w", padx=10)
        self.prompt_box = ScrolledText(root, height=5, wrap="word")
        self.prompt_box.pack(fill=X, padx=10, pady=5)
        self.prompt_box.insert("1.0", "How are Markov models created?")

        button_frame = Frame(root)
        button_frame.pack(fill=X, padx=10, pady=5)

        self.ask_button = Button(button_frame, text="Search", command=self.on_search)
        self.ask_button.pack(side=LEFT, padx=(0, 10))

        Label(button_frame, text="Top N:").pack(side=LEFT)
        self.limit_var = ttk.Combobox(
            button_frame,
            values=[5, 10, 15, 20, 25],
            width=5,
            state="readonly",
        )
        self.limit_var.set(str(RESULTS_LIMIT))
        self.limit_var.pack(side=LEFT, padx=(4, 10))

        self.status_label = Label(root, text="Ready.", anchor="w", justify="left")
        self.status_label.pack(fill=X, padx=10, pady=(0, 6))

        self.spinner = ttk.Progressbar(root, mode="indeterminate", length=220)
        self.spinner.pack(anchor="w", padx=10, pady=(0, 8))

        Label(root, text="Matches:").pack(anchor="w", padx=10)
        self.tree = ttk.Treeview(
            root,
            columns=("rank", "object_name", "object_type", "score"),
            show="headings",
            height=8,
        )
        self.tree.heading("rank", text="#")
        self.tree.heading("object_name", text="Object Name")
        self.tree.heading("object_type", text="Object Type")
        self.tree.heading("score", text="Score")
        self.tree.column("rank", width=50, anchor="center")
        self.tree.column("object_name", width=430, anchor="w")
        self.tree.column("object_type", width=220, anchor="w")
        self.tree.column("score", width=90, anchor="center")
        self.tree.pack(fill=X, padx=10, pady=5)
        self.tree.bind("<<TreeviewSelect>>", self.on_select)

        actions = Frame(root)
        actions.pack(fill=X, padx=10, pady=5)

        self.count_label = Label(actions, text="0 matches")
        self.count_label.pack(side=LEFT, padx=(0, 10))

        self.open_button = Button(
            actions,
            text="Open Link",
            command=self.on_open_link,
            state="disabled",
        )
        self.open_button.pack(side=RIGHT)

        self.load_link_button = Button(
            actions,
            text="Load Link",
            command=self.on_load_linked_content,
            state="disabled",
        )
        self.load_link_button.pack(side=RIGHT, padx=(8, 0))

        self.copy_url_button = Button(
            actions,
            text="Copy URL",
            command=self.on_copy_selected_url,
            state="disabled",
        )
        self.copy_url_button.pack(side=RIGHT, padx=(8, 0))

        self.url_combo = ttk.Combobox(
            actions,
            textvariable=self.selected_url_var,
            state="disabled",
            width=70,
        )
        self.url_combo.pack(side=RIGHT, padx=(0, 8))

        Label(actions, text="Linked URL:").pack(side=RIGHT, padx=(0, 4))

        Label(root, text="Selected item:").pack(anchor="w", padx=10)
        self.details_box = ScrolledText(root, height=8, wrap="word")
        self.details_box.pack(fill=BOTH, expand=False, padx=10, pady=5)

        Label(root, text="Results:").pack(anchor="w", padx=10, pady=(8, 0))
        self.results_notebook = ttk.Notebook(root)
        self.results_notebook.pack(fill=BOTH, expand=True, padx=10, pady=5)

        self.details_frame = Frame(self.results_notebook)
        self.results_notebook.add(self.details_frame, text="Details")
        self.results_details_box = ScrolledText(self.details_frame, wrap="word")
        self.results_details_box.pack(fill=BOTH, expand=True)

        self.link_contents_frame = Frame(self.results_notebook)
        self.results_notebook.add(self.link_contents_frame, text="Link Contents")
        self.link_contents_box = ScrolledText(self.link_contents_frame, wrap="word")
        self.link_contents_box.pack(fill=BOTH, expand=True)

    def set_status(self, text: str):
        self.status_label.config(text=text)
        self.root.update_idletasks()

    def start_spinner(self):
        self.spinner.start(10)

    def stop_spinner(self):
        self.spinner.stop()

    def show_details(self, text: str):
        self.results_details_box.delete("1.0", END)
        self.results_details_box.insert("1.0", text or "")
        self.results_notebook.select(self.details_frame)

    def show_link_contents(self, text: str):
        self.link_contents_box.delete("1.0", END)
        self.link_contents_box.insert("1.0", text or "")
        self.results_notebook.select(self.link_contents_frame)

    def get_selected_url(self) -> str:
        url = self.selected_url_var.get().strip()
        if url:
            return url
        if self.selected_urls:
            return self.selected_urls[0]
        return ""

    def set_url_controls(self):
        if self.selected_urls:
            self.url_combo["values"] = self.selected_urls
            self.selected_url_var.set(self.selected_urls[0])
            self.url_combo.config(state="readonly")
            self.open_button.config(state="normal")
            self.copy_url_button.config(state="normal")
            self.load_link_button.config(state="normal")
        else:
            self.url_combo["values"] = []
            self.selected_url_var.set("")
            self.url_combo.config(state="disabled")
            self.open_button.config(state="disabled")
            self.copy_url_button.config(state="disabled")
            self.load_link_button.config(state="disabled")

    def format_selected_result(self, result: dict) -> str:
        payload = result["payload"]

        lines = [
            f"Rank: {result['rank']}",
            f"Score: {result['score']:.6f}",
            f"Object Name: {payload.get('ObjectName', '')}",
            f"Object Type: {payload.get('ObjectType', '')}",
        ]

        for field in (
            "Description",
            "Utilization",
            "ParametersJson",
            "OutputNotes",
            "ReferencedObjectsJson",
            "SampleCode",
            "SourceFile",
            "SourceURL",
            "URL",
            "GitHubPath",
        ):
            value = payload.get(field)
            if value:
                lines.append("")
                lines.append(f"{field}:")
                if field.endswith("Json") or field in {"ParametersJson", "OutputNotes", "ReferencedObjectsJson"}:
                    lines.append(safe_json_pretty(value))
                else:
                    lines.append(str(value))

        if self.selected_urls:
            lines.append("")
            lines.append("Links:")
            lines.extend(self.selected_urls)

        return "\n".join(lines)

    def on_search(self):
        prompt = self.prompt_box.get("1.0", END).strip()
        if not prompt:
            self.set_status("Enter a prompt first.")
            return

        try:
            limit = int(self.limit_var.get())
        except Exception:
            limit = RESULTS_LIMIT

        def worker():
            try:
                self.root.after(0, lambda: self.ask_button.config(state="disabled"))
                self.root.after(0, self.start_spinner)
                self.root.after(0, lambda: self.set_status("Embedding prompt and searching..."))

                query_vector = embed_text(prompt)

                scored = []
                for record in self.records:
                    score = cosine_similarity(query_vector, record["embedding"])
                    scored.append((score, record))

                scored.sort(key=lambda x: x[0], reverse=True)
                results = []
                for rank, (score, record) in enumerate(scored[:limit], start=1):
                    entry = dict(record)
                    entry["score"] = score
                    entry["rank"] = rank
                    results.append(entry)

                self.root.after(0, lambda: self.populate_results(results))
                self.root.after(0, lambda: self.set_status(f"Done. Found {len(results)} matches."))

            except Exception as e:
                err = str(e)
                self.root.after(0, lambda: self.set_status(f"Error: {err}"))
                self.root.after(0, lambda: self.show_details(f"Error:\n{err}"))
            finally:
                self.root.after(0, self.stop_spinner)
                self.root.after(0, lambda: self.ask_button.config(state="normal"))

        threading.Thread(target=worker, daemon=True).start()

    def populate_results(self, results: list[dict]):
        self.current_results = results
        self.selected_result = None
        self.selected_urls = []

        for item in self.tree.get_children():
            self.tree.delete(item)

        for i, result in enumerate(results):
            payload = result["payload"]
            self.tree.insert(
                "",
                "end",
                iid=str(i),
                values=(
                    result["rank"],
                    payload.get("ObjectName", "<unknown>"),
                    payload.get("ObjectType", ""),
                    f"{result['score']:.4f}",
                ),
            )

        self.count_label.config(text=f"{len(results)} matches")
        self.details_box.delete("1.0", END)
        self.show_details("")
        self.set_url_controls()

    def on_select(self, event=None):
        selection = self.tree.selection()
        if not selection:
            return

        idx = int(selection[0])
        if idx < 0 or idx >= len(self.current_results):
            return

        self.selected_result = self.current_results[idx]
        payload = self.selected_result["payload"]
        self.selected_urls = find_urls_in_payload(payload)

        text = self.format_selected_result(self.selected_result)

        self.details_box.delete("1.0", END)
        self.details_box.insert("1.0", text)
        self.show_details(text)
        self.set_url_controls()

    def on_copy_selected_url(self):
        url = self.get_selected_url()
        if not url:
            self.set_status("No URL available to copy.")
            return

        self.root.clipboard_clear()
        self.root.clipboard_append(url)
        self.root.update()
        self.set_status("URL copied to clipboard.")

    def on_open_link(self):
        url = self.get_selected_url()
        if not url:
            self.set_status("No link available.")
            return

        webbrowser.open_new(url)
        self.set_status("Opened link in browser.")

    def on_load_linked_content(self):
        url = self.get_selected_url()
        if not url:
            self.show_link_contents("No URL found for the selected item.")
            self.set_status("No URL available to load.")
            return

        fetch_url = trusted_link_to_fetchable_url(url)
        if not fetch_url:
            self.show_link_contents(
                "Blocked link. Only links under https://github.com/MapRock/, "
                "https://raw.githubusercontent.com/MapRock/, and https://eugeneasahara.com/ are allowed."
            )
            self.set_status("Restricting access to unknown domains.")
            return

        def worker():
            try:
                self.root.after(0, self.start_spinner)
                self.root.after(0, lambda: self.set_status("Loading linked content..."))
                text = fetch_url_text(fetch_url, timeout=20)
                self.root.after(0, lambda: self.show_link_contents(text))
                self.root.after(0, lambda: self.set_status("Linked content loaded into Link Contents tab."))
            except Exception as e:
                err = str(e)
                self.root.after(0, lambda: self.show_link_contents(f"Failed to load linked content:\n{err}"))
                self.root.after(0, lambda: self.set_status(f"Error loading link: {err}"))
            finally:
                self.root.after(0, self.stop_spinner)

        threading.Thread(target=worker, daemon=True).start()


def main():
    records = load_data_json(EMBEDDINGS_PATH)

    root = Tk()
    StaticSearchUI(root, records)
    root.mainloop()


if __name__ == "__main__":
    main()
