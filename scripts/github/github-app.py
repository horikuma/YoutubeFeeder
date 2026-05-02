#!/usr/bin/env python3

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from github import Auth, Github, GithubIntegration

DEFAULT_CONFIG_PATH = Path(__file__).resolve().parents[2] / "llm-cache" / "github-app.json"
INSTALLATION_ID_KEYS = ("installationId", "installation_id")


def resolve_config_path(config_path: str | None = None) -> Path:
    raw_path = config_path or str(DEFAULT_CONFIG_PATH)
    return Path(raw_path).expanduser().resolve()


def load_settings(config_path: str | None = None) -> dict:
    config_file = resolve_config_path(config_path)
    if not config_file.is_file():
        raise SystemExit(f"GitHub App config not found: {config_file}")
    return json.loads(config_file.read_text(encoding="utf-8"))


def write_settings(config_path: str | None, payload: dict) -> None:
    config_file = resolve_config_path(config_path)
    config_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_config(config_path: str | None = None) -> tuple[str, str]:
    config_file = resolve_config_path(config_path)
    payload = load_settings(config_path)
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


def resolve_installation_id(
    repo_slug: str,
    config_path: str | None = None,
) -> int:
    payload = load_settings(config_path)
    for key in INSTALLATION_ID_KEYS:
        installation_id = payload.get(key)
        if installation_id is not None and str(installation_id).strip():
            try:
                return int(installation_id)
            except ValueError as exc:
                raise SystemExit(f"Config installation id must be numeric: {key}") from exc

    owner, repo_name = split_repo_slug(repo_slug)
    app_id, private_key = load_config(config_path)
    auth = Auth.AppAuth(app_id, private_key)
    integration = GithubIntegration(auth=auth)
    installation = integration.get_repo_installation(owner, repo_name)
    resolved_id = int(installation.id)

    payload["installationId"] = resolved_id
    for key in INSTALLATION_ID_KEYS:
        if key != "installationId":
            payload.pop(key, None)
    write_settings(config_path, payload)
    return resolved_id


def get_operation_mode(config_path: str | None = None) -> str:
    payload = load_settings(config_path)
    mode = str(payload.get("operationMode", "user")).strip().lower()
    if mode not in {"user", "organization"}:
        raise SystemExit(f"operationMode must be 'user' or 'organization': {mode}")
    return mode


def split_repo_slug(repo_slug: str) -> tuple[str, str]:
    if "/" not in repo_slug:
        raise SystemExit(f"repository must be in owner/repo format: {repo_slug}")
    return repo_slug.split("/", 1)


def get_default_assignee(repo_slug: str, config_path: str | None = None) -> str:
    payload = load_settings(config_path)
    assignee = payload.get("defaultAssignee")
    if assignee:
        return str(assignee)
    owner, _ = split_repo_slug(repo_slug)
    return owner


def get_project_settings(repo_slug: str | None = None, config_path: str | None = None) -> dict:
    payload = load_settings(config_path)
    owner = payload.get("projectOwner")
    title = payload.get("projectTitle")
    number = payload.get("projectNumber")
    project_id = payload.get("projectId")
    if repo_slug:
        repo_owner, repo_name = split_repo_slug(repo_slug)
        owner = owner or repo_owner
        title = title or repo_name
    if not owner or not title:
        raise SystemExit("Config must contain projectOwner/projectTitle or infer them from repo")
    return {
        "owner": owner,
        "title": title,
        "number": number,
        "id": project_id,
    }


def get_repository(repo_slug: str, config_path: str | None = None, per_page: int = 100):
    app_id, private_key = load_config(config_path)
    installation_id = resolve_installation_id(repo_slug, config_path=config_path)

    auth = Auth.AppAuth(app_id, private_key)
    integration = GithubIntegration(auth=auth)
    access_token = integration.get_access_token(installation_id)
    github_client = Github(auth=Auth.Token(access_token.token), per_page=per_page)
    return github_client.get_repo(repo_slug)


def get_installation_token(repo_slug: str, config_path: str | None = None) -> str:
    app_id, private_key = load_config(config_path)
    installation_id = resolve_installation_id(repo_slug, config_path=config_path)

    auth = Auth.AppAuth(app_id, private_key)
    integration = GithubIntegration(auth=auth)
    access_token = integration.get_access_token(installation_id)
    return access_token.token


def json_request(url: str, *, method: str, token: str, payload: dict | None = None) -> dict:
    data = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "Content-Type": "application/json",
        "User-Agent": "YoutubeFeeder-Codex",
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")

    request = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(request) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"GitHub API request failed: {method} {url}: {exc.code} {detail}") from exc


def graphql_request(token: str, *, query: str, variables: dict | None = None) -> dict:
    payload = json_request(
        "https://api.github.com/graphql",
        method="POST",
        token=token,
        payload={"query": query, "variables": variables or {}},
    )
    if payload.get("errors"):
        raise SystemExit(f"GitHub GraphQL request failed: {json.dumps(payload['errors'], ensure_ascii=False)}")
    return payload["data"]


def gh_project_list(owner: str) -> list[dict]:
    command = ["gh", "project", "list", "--owner", owner, "--format", "json"]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip()
        raise SystemExit(f"Failed to list GitHub projects through gh: {stderr}")
    payload = json.loads(result.stdout)
    return payload.get("projects", [])


def gh_project_field_list(owner: str, number: int) -> list[dict]:
    command = ["gh", "project", "field-list", str(number), "--owner", owner, "--format", "json"]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip()
        raise SystemExit(f"Failed to list GitHub project fields through gh: {stderr}")
    payload = json.loads(result.stdout)
    return payload.get("fields", [])


def gh_project_field_create(owner: str, number: int, name: str, data_type: str) -> dict:
    command = [
        "gh",
        "project",
        "field-create",
        str(number),
        "--owner",
        owner,
        "--name",
        name,
        "--data-type",
        data_type,
        "--format",
        "json",
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip()
        raise SystemExit(f"Failed to create GitHub project field through gh: {stderr}")
    return json.loads(result.stdout)


def gh_project_item_list(owner: str, number: int, limit: int = 100) -> list[dict]:
    command = [
        "gh",
        "project",
        "item-list",
        str(number),
        "--owner",
        owner,
        "--limit",
        str(limit),
        "--format",
        "json",
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip()
        raise SystemExit(f"Failed to list GitHub project items through gh: {stderr}")
    payload = json.loads(result.stdout)
    return payload.get("items", [])


def gh_add_project_item(*, owner: str, number: int, url: str) -> None:
    command = ["gh", "project", "item-add", str(number), "--owner", owner, "--url", url]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip()
        raise SystemExit(f"Failed to add item to GitHub project through gh: {stderr}")


def gh_project_item_edit_number(*, project_id: str, item_id: str, field_id: str, value: float) -> None:
    command = [
        "gh",
        "project",
        "item-edit",
        "--id",
        item_id,
        "--project-id",
        project_id,
        "--field-id",
        field_id,
        "--number",
        str(value),
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip()
        raise SystemExit(f"Failed to update GitHub project field through gh: {stderr}")


def find_project_field_by_name(*, project: dict, name: str, repo_slug: str, config_path: str | None = None) -> dict | None:
    mode = get_operation_mode(config_path)
    if mode == "user":
        if not project.get("number"):
            raise SystemExit("User mode requires projectNumber to inspect project fields")
        fields = gh_project_field_list(project["owner"], int(project["number"]))
        return next((field for field in fields if field.get("name") == name), None)

    token = get_installation_token(repo_slug, config_path=config_path)
    data = graphql_request(
        token,
        query="""
query($projectId: ID!) {
  node(id: $projectId) {
    ... on ProjectV2 {
      fields(first: 100) {
        nodes {
          ... on ProjectV2FieldCommon {
            id
            name
          }
        }
      }
    }
  }
}
""".strip(),
        variables={"projectId": project["id"]},
    )
    fields = data["node"]["fields"]["nodes"]
    return next((field for field in fields if field.get("name") == name), None)


def ensure_project_number_field(
    *,
    repo_slug: str,
    project: dict,
    name: str,
    config_path: str | None = None,
) -> dict:
    existing = find_project_field_by_name(project=project, name=name, repo_slug=repo_slug, config_path=config_path)
    if existing:
        return existing

    mode = get_operation_mode(config_path)
    if mode == "user":
        if not project.get("number"):
            raise SystemExit("User mode requires projectNumber to create project fields")
        return gh_project_field_create(project["owner"], int(project["number"]), name, "NUMBER")

    token = get_installation_token(repo_slug, config_path=config_path)
    data = graphql_request(
        token,
        query="""
mutation($projectId: ID!, $name: String!) {
  createProjectV2Field(input: {projectId: $projectId, name: $name, dataType: NUMBER}) {
    projectV2Field {
      ... on ProjectV2FieldCommon {
        id
        name
      }
    }
  }
}
""".strip(),
        variables={"projectId": project["id"], "name": name},
    )
    return data["createProjectV2Field"]["projectV2Field"]


def find_project_item_by_content_url(
    *,
    repo_slug: str,
    project: dict,
    content_url: str,
    config_path: str | None = None,
) -> dict:
    mode = get_operation_mode(config_path)
    if mode == "user":
        if not project.get("number"):
            raise SystemExit("User mode requires projectNumber to inspect project items")
        items = gh_project_item_list(project["owner"], int(project["number"]))
        for item in items:
            content = item.get("content") or {}
            if content.get("url") == content_url:
                return item
        raise SystemExit(f"Project item not found for URL: {content_url}")

    token = get_installation_token(repo_slug, config_path=config_path)
    data = graphql_request(
        token,
        query="""
query($projectId: ID!) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 100) {
        nodes {
          id
          content {
            ... on Issue {
              url
            }
            ... on PullRequest {
              url
            }
          }
        }
      }
    }
  }
}
""".strip(),
        variables={"projectId": project["id"]},
    )
    items = data["node"]["items"]["nodes"]
    for item in items:
        content = item.get("content") or {}
        if content.get("url") == content_url:
            return item
    raise SystemExit(f"Project item not found for URL: {content_url}")


def set_project_number_field_value(
    *,
    repo_slug: str,
    project: dict,
    content_url: str,
    field_name: str,
    value: float,
    config_path: str | None = None,
) -> dict:
    field = ensure_project_number_field(
        repo_slug=repo_slug,
        project=project,
        name=field_name,
        config_path=config_path,
    )
    item = find_project_item_by_content_url(
        repo_slug=repo_slug,
        project=project,
        content_url=content_url,
        config_path=config_path,
    )

    mode = get_operation_mode(config_path)
    if mode == "user":
        gh_project_item_edit_number(
            project_id=project["id"],
            item_id=item["id"],
            field_id=field["id"],
            value=value,
        )
        return {"field": field, "item": item}

    token = get_installation_token(repo_slug, config_path=config_path)
    graphql_request(
        token,
        query="""
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: Float!) {
  updateProjectV2ItemFieldValue(
    input: {
      projectId: $projectId
      itemId: $itemId
      fieldId: $fieldId
      value: {number: $value}
    }
  ) {
    projectV2Item {
      id
    }
  }
}
""".strip(),
        variables={
            "projectId": project["id"],
            "itemId": item["id"],
            "fieldId": field["id"],
            "value": value,
        },
    )
    return {"field": field, "item": item}


def add_content_to_project(
    *,
    repo_slug: str,
    content_node_id: str,
    content_url: str,
    project: dict,
    config_path: str | None = None,
) -> None:
    mode = get_operation_mode(config_path)
    if mode == "user":
        if not project.get("number"):
            raise SystemExit("User mode requires projectNumber for gh project item-add")
        gh_add_project_item(owner=project["owner"], number=int(project["number"]), url=content_url)
        return

    if not project.get("id"):
        raise SystemExit("Organization mode requires projectId for addProjectV2ItemById")
    token = get_installation_token(repo_slug, config_path=config_path)
    graphql_request(
        token,
        query="""
mutation($projectId: ID!, $contentId: ID!) {
  addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
    item {
      id
    }
  }
}
""".strip(),
        variables={"projectId": project["id"], "contentId": content_node_id},
    )


def add_assignees_to_issue(
    *,
    repo_slug: str,
    issue_number: int,
    assignees: list[str],
    config_path: str | None = None,
) -> dict:
    owner, repo_name = split_repo_slug(repo_slug)
    token = get_installation_token(repo_slug, config_path=config_path)
    return json_request(
        f"https://api.github.com/repos/{owner}/{repo_name}/issues/{issue_number}/assignees",
        method="POST",
        token=token,
        payload={"assignees": assignees},
    )
