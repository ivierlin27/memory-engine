#!/usr/bin/env python3
"""Scan recent structured memory for contradictions and emit derived outputs."""

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


def insert_finding(finding: dict[str, Any], planka_card_id: str | None) -> None:
    container = env("POSTGRES_CONTAINER_NAME", "memory-postgres")
    user = env("POSTGRES_USER", "memory")
    database = env("POSTGRES_DB", "memory")
    row = io.StringIO()
    writer = csv.writer(row)
    writer.writerow(
        [
            "weekly",
            finding["title"],
            finding.get("summary", ""),
            finding.get("severity", "medium"),
            "open",
            env("MEMORY_ENGINE_CONTRADICTION_PRINCIPAL", "system:contradiction-scan"),
            json.dumps(finding.get("evidence", [])),
            planka_card_id or "",
            json.dumps({"generator": "scripts/scan_contradictions.py"}),
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
                "COPY contradiction_findings "
                "(scope, title, summary, severity, status, principal, evidence, planka_card_id, metadata) "
                "FROM STDIN WITH (FORMAT csv)"
            ),
        ],
        input=row.getvalue(),
        text=True,
        check=True,
    )


def call_openai_json(prompt: str) -> list[dict[str, Any]]:
    payload = {
        "model": llm_model(),
        "temperature": 0.0,
        "messages": [
            {
                "role": "system",
                "content": (
                    "Identify contradictions and return JSON only. "
                    "Use this exact schema: "
                    "[{"
                    "\"title\": string, "
                    "\"summary\": string, "
                    "\"severity\": \"low\"|\"medium\"|\"high\", "
                    "\"evidence\": [{\"type\": string, \"id\": string, \"detail\": string}]"
                    "}]. "
                    "If there are no meaningful contradictions, return []."
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
    content = body["choices"][0]["message"]["content"].strip()
    return json.loads(content)


def create_planka_card(finding: dict[str, Any]) -> str | None:
    list_id = env("PLANKA_REVIEW_LIST_ID")
    base_url = env("MEMORY_ENGINE_PLANKA_URL")
    token = env("PLANKA_API_TOKEN")
    if not (list_id and base_url and token):
        return None

    payload = {
        "type": "project",
        "position": 65535,
        "name": finding["title"][:1024],
        "description": (
            finding.get("summary", "")[:4000]
            + "\n\nEvidence:\n"
            + json.dumps(finding.get("evidence", []), indent=2)[:3500]
        ),
    }
    req = request.Request(
        url=f"{base_url.rstrip('/')}/api/lists/{list_id}/cards",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
        },
        method="POST",
    )
    with request.urlopen(req, timeout=60) as response:
        body = json.loads(response.read().decode("utf-8"))
    item = body.get("item") or body
    card_id = item.get("id")
    return str(card_id) if card_id else None


def render_markdown(findings: list[dict[str, Any]]) -> str:
    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    lines = [
        "---",
        "derived: true",
        f"generated_at: {json.dumps(generated_at)}",
        'scope: "weekly-tensions"',
        f"principal: {json.dumps(env('MEMORY_ENGINE_CONTRADICTION_PRINCIPAL', 'system:contradiction-scan'))}",
        "---",
        "",
        "# Open Tensions",
        "",
    ]
    if not findings:
        lines.append("No meaningful contradictions detected in the configured window.")
        return "\n".join(lines) + "\n"

    for finding in findings:
        lines.extend(
            [
                f"## {finding['title']}",
                "",
                f"Severity: **{finding.get('severity', 'medium')}**",
                "",
                finding.get("summary", ""),
                "",
                "Evidence:",
            ]
        )
        for evidence in finding.get("evidence", []):
            detail = evidence.get("detail", "").strip()
            lines.append(
                f"- `{evidence.get('type', 'unknown')}` `{evidence.get('id', 'unknown')}`"
                + (f": {detail}" if detail else "")
            )
        lines.append("")
    return "\n".join(lines) + "\n"


def main() -> int:
    load_dotenv(ROOT / ".env")
    days = int(env("MEMORY_ENGINE_CONTRADICTION_DAYS", "14"))
    compiled_dir = Path(env("MEMORY_ENGINE_COMPILED_DIR", str(ROOT / "obsidian_vault" / "compiled" / "current")))
    compiled_dir.mkdir(parents=True, exist_ok=True)

    evidence = run_psql_json(
        f"""
        SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
        FROM (
          SELECT 'session' AS type, id::text, created_at, source, principal,
                 raw_summary AS detail, git_ref, artifact_url
          FROM sessions
          WHERE created_at > NOW() - INTERVAL '{days} days'
          UNION ALL
          SELECT 'inbox' AS type, id::text, created_at, item_type AS source, principal,
                 COALESCE(summary, raw_input) AS detail, git_ref, artifact_url
          FROM inbox
          WHERE created_at > NOW() - INTERVAL '{days} days'
        ) t
        """
    )

    prompt = (
        "Analyze the following records for unresolved contradictions, mismatched "
        "plans vs claims, or decisions that point in opposing directions.\n\n"
        f"Evidence JSON:\n{json.dumps(evidence, indent=2)}\n"
    )
    findings = call_openai_json(prompt)

    output_path = compiled_dir / "open-tensions.md"
    output_path.write_text(render_markdown(findings), encoding="utf-8")

    for finding in findings:
        card_id = create_planka_card(finding)
        insert_finding(finding, card_id)

    print(f"Wrote {output_path.relative_to(ROOT)}")
    print(f"Findings: {len(findings)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        print(exc.stderr or exc.stdout or str(exc), file=sys.stderr)
        raise
