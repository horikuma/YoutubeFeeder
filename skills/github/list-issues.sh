#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CONFIG_PATH="${GITHUB_APP_CONFIG_PATH:-$REPO_ROOT/secrets/github-app-bot.json}"
REPO_SLUG="${GITHUB_REPOSITORY:-}"
STATE="open"
PER_PAGE="100"
PAGE="1"
INCLUDE_PULLS=0

usage() {
  cat <<'EOF' >&2
Usage: list-issues.sh [--repo owner/repo] [--state open|closed|all] [--per-page N] [--page N] [--include-pulls] [--config path]
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_SLUG="$2"
      shift 2
      ;;
    --state)
      STATE="$2"
      shift 2
      ;;
    --per-page)
      PER_PAGE="$2"
      shift 2
      ;;
    --page)
      PAGE="$2"
      shift 2
      ;;
    --include-pulls)
      INCLUDE_PULLS=1
      shift
      ;;
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done

if [[ -z "$REPO_SLUG" ]]; then
  echo "--repo or GITHUB_REPOSITORY is required" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "GitHub App config not found: $CONFIG_PATH" >&2
  exit 1
fi

if [[ ! "$REPO_SLUG" =~ ^[^/]+/[^/]+$ ]]; then
  echo "Repository must be in owner/repo format: $REPO_SLUG" >&2
  exit 1
fi

OWNER="${REPO_SLUG%%/*}"
REPO_NAME="${REPO_SLUG#*/}"

APP_ID="$(jq -r '.appId // .app_id // empty' "$CONFIG_PATH")"
PRIVATE_KEY_PATH="$(jq -r '.privateKeyPath // .private_key_path // empty' "$CONFIG_PATH")"

if [[ -z "$APP_ID" || -z "$PRIVATE_KEY_PATH" ]]; then
  echo "Config must contain appId and privateKeyPath: $CONFIG_PATH" >&2
  exit 1
fi

if [[ "$PRIVATE_KEY_PATH" != /* ]]; then
  CONFIG_DIR="$(cd "$(dirname "$CONFIG_PATH")" && pwd)"
  PRIVATE_KEY_PATH="$CONFIG_DIR/$PRIVATE_KEY_PATH"
fi

if [[ ! -f "$PRIVATE_KEY_PATH" ]]; then
  echo "Private key not found: $PRIVATE_KEY_PATH" >&2
  exit 1
fi

base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

make_jwt() {
  local now iat exp header payload header_b64 payload_b64 signing_input signature_b64

  now="$(date +%s)"
  iat="$((now - 60))"
  exp="$((now + 540))"

  header='{"alg":"RS256","typ":"JWT"}'
  payload="{\"iat\":${iat},\"exp\":${exp},\"iss\":${APP_ID}}"

  header_b64="$(printf '%s' "$header" | base64url)"
  payload_b64="$(printf '%s' "$payload" | base64url)"
  signing_input="${header_b64}.${payload_b64}"
  signature_b64="$(
    printf '%s' "$signing_input" \
      | openssl dgst -binary -sha256 -sign "$PRIVATE_KEY_PATH" \
      | base64url
  )"

  printf '%s.%s\n' "$signing_input" "$signature_b64"
}

api_request() {
  local method="$1"
  local url="$2"
  local auth_header="$3"
  local body="${4:-}"
  local response http_code response_body

  if [[ -n "$body" ]]; then
    response="$(
      curl --silent --show-error --request "$method" \
        --url "$url" \
        --header "Accept: application/vnd.github+json" \
        --header "Authorization: Bearer $auth_header" \
        --header "X-GitHub-Api-Version: 2022-11-28" \
        --header "Content-Type: application/json" \
        --data "$body" \
        --write-out $'\n%{http_code}'
    )"
  else
    response="$(
      curl --silent --show-error --request "$method" \
        --url "$url" \
        --header "Accept: application/vnd.github+json" \
        --header "Authorization: Bearer $auth_header" \
        --header "X-GitHub-Api-Version: 2022-11-28" \
        --write-out $'\n%{http_code}'
    )"
  fi

  http_code="${response##*$'\n'}"
  response_body="${response%$'\n'*}"

  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    echo "GitHub API request failed: ${method} ${url} (${http_code})" >&2
    echo "$response_body" | jq -c '{message, documentation_url, errors}' >&2 || echo "$response_body" >&2
    exit 1
  fi

  printf '%s' "$response_body"
}

JWT="$(make_jwt)"
INSTALLATION_JSON="$(
  api_request \
    GET \
    "https://api.github.com/repos/${OWNER}/${REPO_NAME}/installation" \
    "$JWT"
)"
INSTALLATION_ID="$(printf '%s' "$INSTALLATION_JSON" | jq -r '.id')"

if [[ -z "$INSTALLATION_ID" || "$INSTALLATION_ID" == "null" ]]; then
  echo "Failed to resolve installation id for ${REPO_SLUG}" >&2
  exit 1
fi

ACCESS_TOKEN_JSON="$(
  api_request \
    POST \
    "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens" \
    "$JWT" \
    '{}'
)"
ACCESS_TOKEN="$(printf '%s' "$ACCESS_TOKEN_JSON" | jq -r '.token')"

if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
  echo "Failed to mint installation token for ${REPO_SLUG}" >&2
  exit 1
fi

ISSUES_JSON="$(
  curl --silent --show-error --get \
    --url "https://api.github.com/repos/${OWNER}/${REPO_NAME}/issues" \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    --header "X-GitHub-Api-Version: 2022-11-28" \
    --data-urlencode "state=${STATE}" \
    --data-urlencode "per_page=${PER_PAGE}" \
    --data-urlencode "page=${PAGE}"
)"

if [[ "$INCLUDE_PULLS" -eq 1 ]]; then
  printf '%s\n' "$ISSUES_JSON" | jq '.'
else
  printf '%s\n' "$ISSUES_JSON" | jq '[.[] | select(has("pull_request") | not)]'
fi
