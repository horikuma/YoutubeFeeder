#!/usr/bin/env python3

from __future__ import annotations

import json
import os
from pathlib import Path

from github import Auth, Github, GithubIntegration

DEFAULT_CONFIG_PATH = Path(__file__).resolve().parents[2] / "secrets" / "github-app-bot.json"


def resolve_config_path(config_path: str | None = None) -> Path:
    raw_path = config_path or os.getenv("GITHUB_APP_CONFIG_PATH") or str(DEFAULT_CONFIG_PATH)
    return Path(raw_path).expanduser().resolve()


def load_config(config_path: str | None = None) -> tuple[str, str]:
    config_file = resolve_config_path(config_path)
    if not config_file.is_file():
        raise SystemExit(f"GitHub App config not found: {config_file}")

    payload = json.loads(config_file.read_text())
    app_id = payload.get("appId") or payload.get("app_id")
    private_key_path = payload.get("privateKeyPath") or payload.get("private_key_path")

    if not app_id or not private_key_path:
        raise SystemExit(f"Config must contain appId and privateKeyPath: {config_file}")

    private_key_file = Path(private_key_path)
    if not private_key_file.is_absolute():
        private_key_file = (config_file.parent / private_key_file).resolve()

    if not private_key_file.is_file():
        raise SystemExit(f"Private key not found: {private_key_file}")

    return str(app_id), private_key_file.read_text()


def get_repository(repo_slug: str, config_path: str | None = None, per_page: int = 100):
    if "/" not in repo_slug:
        raise SystemExit(f"repository must be in owner/repo format: {repo_slug}")

    owner, repo_name = repo_slug.split("/", 1)
    app_id, private_key = load_config(config_path)

    auth = Auth.AppAuth(app_id, private_key)
    integration = GithubIntegration(auth=auth)
    installation = integration.get_repo_installation(owner, repo_name)
    access_token = integration.get_access_token(installation.id)
    github_client = Github(auth=Auth.Token(access_token.token), per_page=per_page)
    return github_client.get_repo(repo_slug)


def ensure_label(repository, name: str, color: str, description: str):
    try:
        return repository.get_label(name)
    except Exception:
        return repository.create_label(name=name, color=color, description=description)
