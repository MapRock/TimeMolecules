# shared_llm.py
from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path

import ollama
from dotenv import load_dotenv
from openai import OpenAI


def load_env_upward(start_file: str | Path) -> Path | None:
    current = Path(start_file).resolve()
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

    return env_path


def clean_for_embedding(text: str) -> str:
    if not text:
        return ""

    text = str(text)
    text = text.replace("[", "").replace("]", "")
    text = text.replace("{", "").replace("}", "")
    text = text.replace("(", "").replace(")", "")
    text = text.replace("dbo.", "")
    text = re.sub(r"[_\\-]+", " ", text)
    text = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", text)
    text = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


@dataclass
class LLMConfig:
    chat_llm: str
    embed_llm: str
    chat_model: str
    embed_model: str
    openai_api_key: str | None
    xai_api_key: str | None          # ← NEW for Grok
    max_tokens: int
    ollama_host: str | None
    ollama_ctx: int
    qdrant_base_path: str
    qdrant_path: str
    collection_name: str


def build_qdrant_path(base_path: str, embed_llm: str, embed_model: str) -> str:
    safe_model = embed_model.replace("/", "_").replace(":", "_").replace("-", "_")
    return f"{base_path}_{embed_llm}_{safe_model}"


def read_llm_config() -> LLMConfig:
    chat_llm = os.getenv("LLM", "ollama").lower()
    embed_llm = os.getenv("EMBED_LLM", "ollama").lower()

    # Chat model selection
    if chat_llm == "grok":
        chat_model = os.getenv("CHAT_MODEL", "grok-4")
    elif chat_llm == "openai":
        chat_model = os.getenv("CHATGPT_MODEL", "gpt-4o-mini")
    else:
        chat_model = os.getenv("OLLAMA_CHAT_MODEL", "llama3.2")

    # Embed model
    if embed_llm == "openai":
        embed_model = os.getenv("CHATGPT_EMBEDDING_MODEL", "text-embedding-3-small")
    else:
        embed_model = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")

    qdrant_base_path = os.getenv("QDRANT_PATH", "./qdrant_data")
    qdrant_path = build_qdrant_path(qdrant_base_path, embed_llm, embed_model)

    return LLMConfig(
        chat_llm=chat_llm,
        embed_llm=embed_llm,
        chat_model=chat_model,
        embed_model=embed_model,
        openai_api_key=os.getenv("OPENAI_API_KEY"),
        xai_api_key=os.getenv("XAI_API_KEY"),          # ← NEW
        max_tokens=int(os.getenv("CHATGPT_MAX_RESPONSE_TOKENS", "500")),
        ollama_host=os.getenv("OLLAMA_HOST"),
        ollama_ctx=int(os.getenv("OLLAMA_CTX", "8192")),
        qdrant_base_path=qdrant_base_path,
        qdrant_path=qdrant_path,
        collection_name=os.getenv("QDRANT_COLLECTION_NAME", "time_molecules_directory"),
    )


class SharedLLM:
    def __init__(self, config: LLMConfig):
        self.config = config
        self.openai_client = None
        self.ollama_client = ollama.Client(host=config.ollama_host) if config.ollama_host else ollama.Client()

        # Initialize OpenAI-compatible client for OpenAI OR Grok
        if config.chat_llm in ("openai", "grok") or config.embed_llm == "openai":
            if config.chat_llm == "grok":
                api_key = config.xai_api_key
                base_url = "https://api.x.ai/v1"
                if not api_key:
                    raise RuntimeError("XAI_API_KEY must be set to use Grok.")
            else:
                api_key = config.openai_api_key
                base_url = None
                if not api_key:
                    raise RuntimeError("OPENAI_API_KEY must be set to use OpenAI.")

            self.openai_client = OpenAI(
                api_key=api_key,
                base_url=base_url,
            )

    def chat_once(self, messages: list[dict], max_tokens: int | None = None) -> str:
        max_tokens = max_tokens or self.config.max_tokens

        if self.config.chat_llm in ("openai", "grok"):
            if self.openai_client is None:
                raise RuntimeError("OpenAI/Grok client is not initialized.")
            response = self.openai_client.chat.completions.create(
                model=self.config.chat_model,
                messages=messages,
                max_tokens=max_tokens,
            )
            return (response.choices[0].message.content or "").strip()

        if self.config.chat_llm == "ollama":
            response = self.ollama_client.chat(
                model=os.getenv("OLLAMA_CHAT_MODEL", "llama3.2"),
                messages=messages,
                options={"num_ctx": self.config.ollama_ctx},
            )
            return response.get("message", {}).get("content", "").strip()

        raise ValueError(f"Unsupported chat_llm: {self.config.chat_llm}")

    def embed_text(self, text: str) -> list[float]:
        cleaned = clean_for_embedding(text)

        if self.config.embed_llm == "openai":
            if self.openai_client is None:
                raise RuntimeError("OpenAI client is not initialized.")
            response = self.openai_client.embeddings.create(
                model=self.config.embed_model,
                input=cleaned,
            )
            return response.data[0].embedding

        if self.config.embed_llm == "ollama":
            response = self.ollama_client.embed(
                model=self.config.embed_model,
                input=cleaned,
            )
            embeddings = response.get("embeddings")
            if not embeddings or not embeddings[0]:
                raise ValueError(f"Ollama returned no embedding for model {self.config.embed_model}")
            return embeddings[0]

        raise ValueError(f"Unsupported embed_llm: {self.config.embed_llm}")