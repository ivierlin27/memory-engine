#!/usr/bin/env python3
"""Compile recent structured memory into derived markdown.

Designed to run on the Docker host that owns the memory-engine stack.
It reads recent sessions and inbox items from Postgres via the running
`memory-postgres` container, calls an OpenAI-compatible endpoint, writes a
derived markdown artifact under `obsidian_vault/compiled/`, and records a row
in `compiled_documents`.
"""

from __future__ import annotations

import csv
import io
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib import request


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCOPE = os.environ.get("MEMORY_ENGINE_COMPILER_SCOPE", "weekly")
DEFAULT_DAYS = int(os.environ.get("MEMORY_ENGINE_COMPILER_DAYS", "7"))


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key, value)


def env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def llm_base_url() -> str:
    explicit = env("MEMORY_ENGINE_LLM_BASE_URL")
    if explicit:
        return explicit.rstrip("/")
    openai_base = env("OPENAI_BASE_URL")
    if openai_base:
        return openai_base.rstrip("/")
    host = env("LM_STUDIO_HOST", "127.0.0.1")
    port = env("LM_STUDIO_PORT", "1234")
    return f"http://{host}:{port}/v1"


def llm_model() -> str:
    return (
        env("MEMORY_ENGINE_STRONG_MODEL")
        or env("LLM_MODEL")
        or "qwen2.5-32b-instruct"
    )


def run_psql_json(sql: str) -> Any:
    container = env("POSTGRES_CONTAINER_NAME", "memory-postgres")
    user = env("POSTGRES_USER", "memory")
    database = env("POSTGRES_DB", "memory")
    copy_sql = f"COPY ({sql}) TO STDOUT"
    result = subprocess.run(
        [
            "docker",
            "exec",
            "-i",
            container,
            "psql",
            "-t",
            "-A",
            "-U",
            user,
            "-d",
            database,
            "-c",
            copy_sql,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    text = result.stdout.strip() or "null"
    return json.loads(text)


def record_compiled_document(scope: str, title: str, relative_path: str, sources: list[dict[str, Any]]) -> None:
    container = env("POSTGRES_CONTAINER_NAME", "memory-postgres")
    user = env("POSTGRES_USER", "memory")
    database = env("POSTGRES_DB", "memory")
    row = io.StringIO()
    writer = csv.writer(row)
    writer.writerow(
        [
            scope,
            title,
            relative_path,
            env("MEMORY_ENGINE_COMPILER_PRINCIPAL", "system:wiki-compiler"),
            json.dumps(sources),
            json.dumps({"generator": "scripts/wiki_compile.py"}),
        ]
    )
    subprocess.run(
        [
            "docker",
            "exec",
            "-i",
            container,
            "psql",
            "-v",
            "ON_ERROR_STOP=1",
            "-U",
            user,
            "-d",
            database,
            "-c",
            (
                "COPY compiled_documents "
                "(scope, title, relative_path, principal, source_refs, metadata) "
                "FROM STDIN WITH (FORMAT csv)"
            ),
        ],
        input=row.getvalue(),
        text=True,
        check=True,
    )


def call_openai_compatible(prompt: str) -> str:
    payload = {
        "model": llm_model(),
        "temperature": 0.2,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You write cautious, source-aware operational summaries. "
                    "Only make claims supported by the provided records. "
                    "Call out uncertainty and preserve contradictions."
                ),
            },
            {"role": "user", "content": prompt},
        ],
    }
    req = request.Request(
        url=f"{llm_base_url()}/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {env('OPENAI_API_KEY', 'lm-studio')}",
        },
        method="POST",
    )
    with request.urlopen(req, timeout=180) as response:
        body = json.loads(response.read().decode("utf-8"))
    return body["choices"][0]["message"]["content"].strip()


def build_prompt(scope: str, sessions: list[dict[str, Any]], inbox_items: list[dict[str, Any]]) -> str:
    return (
        f"Create a derived markdown briefing for scope={scope}.\n\n"
        "Requirements:\n"
        "- Output markdown only, no surrounding explanation.\n"
        "- Include sections: Summary, Key Changes, Active Work, Open Questions.\n"
        "- Preserve contradictions instead of smoothing them over.\n"
        "- Mention source ids inline when useful.\n"
        "- Do not invent source refs.\n\n"
        f"Sessions JSON:\n{json.dumps(sessions, indent=2)}\n\n"
        f"Inbox JSON:\n{json.dumps(inbox_items, indent=2)}\n"
    )


def markdown_frontmatter(scope: str, sources: list[dict[str, Any]]) -> str:
    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    frontmatter = {
        "derived": True,
        "generated_at": generated_at,
        "scope": scope,
        "principal": env("MEMORY_ENGINE_COMPILER_PRINCIPAL", "system:wiki-compiler"),
        "sources": sources,
    }
    lines = ["---"]
    for key, value in frontmatter.items():
        lines.append(f"{key}: {json.dumps(value)}")
    lines.append("---")
    return "\n".join(lines)


def collect_sources(records: list[dict[str, Any]], record_type: str) -> list[dict[str, Any]]:
    refs = []
    for record in records:
        ref = {"type": record_type}
        if "id" in record:
            ref["id"] = record["id"]
        if "git_ref" in record and record["git_ref"]:
            ref["git_ref"] = record["git_ref"]
        if "artifact_url" in record and record["artifact_url"]:
            ref["artifact_url"] = record["artifact_url"]
        refs.append(ref)
    return refs


def main() -> int:
    load_dotenv(ROOT / ".env")
    scope = DEFAULT_SCOPE
    days = DEFAULT_DAYS
    compiled_dir = Path(env("MEMORY_ENGINE_COMPILED_DIR", str(ROOT / "obsidian_vault" / "compiled" / "current")))
    compiled_dir.mkdir(parents=True, exist_ok=True)

    sessions = run_psql_json(
        f"""
        SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
        FROM (
          SELECT id::text, created_at, source, principal, raw_summary,
                 projects_touched, decisions_made, open_questions,
                 git_ref, artifact_url
          FROM sessions
          WHERE created_at > NOW() - INTERVAL '{days} days'
          ORDER BY created_at DESC
          LIMIT 20
        ) t
        """
    )
    inbox_items = run_psql_json(
        f"""
        SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
        FROM (
          SELECT id::text, created_at, item_type, principal, title, summary,
                 status, recommendation, git_ref, artifact_url
          FROM inbox
          WHERE created_at > NOW() - INTERVAL '{days} days'
          ORDER BY created_at DESC
          LIMIT 30
        ) t
        """
    )

    prompt = build_prompt(scope, sessions, inbox_items)
    compiled_markdown = call_openai_compatible(prompt)
    sources = collect_sources(sessions, "session") + collect_sources(inbox_items, "inbox")
    output_path = compiled_dir / f"{scope}-briefing.md"
    output_path.write_text(
        markdown_frontmatter(scope, sources)
        + "\n\n"
        + compiled_markdown.rstrip()
        + "\n",
        encoding="utf-8",
    )

    relative_path = output_path.relative_to(ROOT).as_posix()
    record_compiled_document(scope, f"{scope.title()} briefing", relative_path, sources)
    print(f"Wrote {relative_path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        print(exc.stderr or exc.stdout or str(exc), file=sys.stderr)
        raise
