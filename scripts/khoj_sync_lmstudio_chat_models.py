#!/usr/bin/env python3
"""
Sync Khoj ChatModel rows from LM Studio (or any OpenAI-compatible server)
GET /v1/models, using the same OPENAI_* env vars as the Khoj container.

Run via the helper (pipes this file into the container — no bind-mount):

  ./scripts/sync-khoj-chat-models.sh

Or manually:

  docker compose exec -T khoj env PYTHONPATH=/app/src python3 - < scripts/khoj_sync_lmstudio_chat_models.py

Options:
  --dry-run    Print actions without writing to the database
  --prune      Delete ChatModel rows tied to the synced AiModelApi whose IDs
               are no longer returned by /v1/models (does not touch other APIs)

Env (inherited from docker-compose):
  OPENAI_BASE_URL   e.g. http://192.168.1.x:1234/v1
  OPENAI_API_KEY    Sent as Bearer token when querying /v1/models

Optional:
  KHOJ_LMSTUDIO_API_NAME       Default: "LM Studio (synced)"
  KHOJ_SYNC_MAX_PROMPT_SIZE    Default: 32768
  KHOJ_SYNC_MODEL_ALLOWLIST    Optional comma-separated model ids to sync

Note: --prune only deletes ChatModel rows that are still unreferenced (no agent,
server default slot, or user setting points at them).
"""

from __future__ import annotations

import argparse
import json
import os
import ssl
import sys
import urllib.error
import urllib.request
from urllib.parse import urlparse


def _validate_openai_base_url(base_url: str) -> None:
    """Catch common .env mistakes (e.g. LM_STUDIO_HOST=LXC_IP=192.168...) before HTTP."""
    try:
        u = urlparse(base_url.strip())
    except ValueError as e:
        raise RuntimeError(f"Invalid OPENAI_BASE_URL: {base_url!r}") from e
    netloc = u.netloc or ""
    if "=" in netloc:
        raise RuntimeError(
            "OPENAI_BASE_URL hostname is malformed (contains '=').\n"
            "  Often: LM_STUDIO_HOST was set like LXC_IP=192.168.x.x — include only the address.\n"
            "  Fix .env:  LM_STUDIO_HOST=192.168.x.x\n"
            "  Then reload Khoj env:  docker compose up -d khoj"
        )
    host = u.hostname
    if not host:
        raise RuntimeError(
            "OPENAI_BASE_URL has no hostname (check LM_STUDIO_HOST in .env — use the LM Studio "
            "machine IP or DNS, not an empty line or placeholder)."
        )


def _models_url(openai_base: str) -> str:
    base = openai_base.strip().rstrip("/")
    if not base.endswith("/v1"):
        base = base + "/v1"
    return base + "/models"


def _fetch_model_ids(base_url: str, api_key: str) -> list[str]:
    url = _models_url(base_url)
    headers = {}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    req = urllib.request.Request(url, headers=headers, method="GET")
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, timeout=45, context=ctx) as resp:
            raw = resp.read().decode()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code} from {url}: {e.read().decode(errors='replace')}") from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"Could not reach {url}: {e}") from e

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Invalid JSON from {url}") from e

    data = payload.get("data")
    if not isinstance(data, list):
        raise RuntimeError(f"Unexpected /v1/models shape (no list 'data'): {payload!r}")

    ids: list[str] = []
    for item in data:
        if isinstance(item, dict) and "id" in item:
            mid = item["id"]
            if isinstance(mid, str) and mid:
                ids.append(mid)

    # Stable order for predictable diffs
    return sorted(set(ids))


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync Khoj chat models from OpenAI-compatible /v1/models")
    parser.add_argument("--dry-run", action="store_true", help="Do not write to the database")
    parser.add_argument(
        "--prune",
        action="store_true",
        help="Remove ChatModel rows for this API that are missing from /v1/models",
    )
    args = parser.parse_args()

    base_url = os.environ.get("OPENAI_BASE_URL", "").strip()
    if not base_url:
        print("error: OPENAI_BASE_URL is not set", file=sys.stderr)
        return 2

    try:
        _validate_openai_base_url(base_url)
    except RuntimeError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    api_key = os.environ.get("OPENAI_API_KEY", "") or ""

    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "khoj.app.settings")

    try:
        model_ids = _fetch_model_ids(base_url, api_key)
    except RuntimeError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    if not model_ids:
        print("warning: /v1/models returned no models — nothing to sync", file=sys.stderr)

    allowlist = {
        item.strip()
        for item in os.environ.get("KHOJ_SYNC_MODEL_ALLOWLIST", "").split(",")
        if item.strip()
    }
    if allowlist:
        model_ids = [model_id for model_id in model_ids if model_id in allowlist]
        if not model_ids:
            print("warning: KHOJ_SYNC_MODEL_ALLOWLIST filtered out all models — nothing to sync", file=sys.stderr)

    api_name = os.environ.get("KHOJ_LMSTUDIO_API_NAME", "LM Studio (synced)")
    max_prompt = int(os.environ.get("KHOJ_SYNC_MAX_PROMPT_SIZE", "32768"))

    # Django imports after env is ready
    import django

    django.setup()

    from django.db.models import Q

    from khoj.database.models import Agent, AiModelApi, ChatModel, ServerChatSettings, UserConversationConfig

    # Django URLField: store without trailing slash
    api_base_store = base_url.rstrip("/")

    if args.dry_run:
        print(f"[dry-run] Would upsert AiModelApi name={api_name!r} api_base_url={api_base_store!r}")
        print(f"[dry-run] Would upsert {len(model_ids)} ChatModel row(s): {', '.join(model_ids) or '(none)'}")
        if args.prune:
            print("[dry-run] Would prune stale ChatModel rows for this AiModelApi")
        return 0

    api, _created = AiModelApi.objects.update_or_create(
        name=api_name,
        defaults={
            "api_key": api_key or "lm-studio",
            "api_base_url": api_base_store or None,
        },
    )

    created_n = updated_n = 0
    for mid in model_ids:
        _obj, was_created = ChatModel.objects.update_or_create(
            ai_model_api=api,
            name=mid,
            defaults={
                "friendly_name": mid,
                "model_type": ChatModel.ModelType.OPENAI,
                "max_prompt_size": max_prompt,
                "tokenizer": None,
                "description": "Auto-synced from OpenAI-compatible GET /v1/models.",
                "vision_enabled": False,
            },
        )
        if was_created:
            created_n += 1
        else:
            updated_n += 1

    skipped_prune = []
    pruned_chat_models = 0
    if args.prune:
        stale = list(ChatModel.objects.filter(ai_model_api=api).exclude(name__in=model_ids))
        safe_pks = []
        for cm in stale:

            def _referenced() -> bool:
                if Agent.objects.filter(chat_model=cm).exists():
                    return True
                if UserConversationConfig.objects.filter(setting=cm).exists():
                    return True
                q = (
                    Q(chat_default=cm)
                    | Q(chat_advanced=cm)
                    | Q(think_free_fast=cm)
                    | Q(think_free_deep=cm)
                    | Q(think_paid_fast=cm)
                    | Q(think_paid_deep=cm)
                )
                return ServerChatSettings.objects.filter(q).exists()

            if _referenced():
                skipped_prune.append(cm.name)
            else:
                safe_pks.append(cm.pk)

        if safe_pks:
            ChatModel.objects.filter(pk__in=safe_pks).delete()
            pruned_chat_models = len(safe_pks)

    print(
        f"Synced AiModelApi {api_name!r} ← { _models_url(base_url) }\n"
        f"  ChatModel: {created_n} created, {updated_n} updated, {len(model_ids)} total from API"
    )
    if args.prune:
        print(f"  Prune: removed {pruned_chat_models} unreferenced ChatModel row(s)")
        if skipped_prune:
            print(f"  Prune skipped (still referenced): {', '.join(sorted(skipped_prune))}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
