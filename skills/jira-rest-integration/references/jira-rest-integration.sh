#!/usr/bin/env bash

# Helper functions for Jira Cloud REST API v3.
# Usage from a project directory:
#   source /path/to/references/jira-rest-integration.sh
#   jira_init
#   jira_get_issue PROJ-123

jira_project_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

jira_config_path() {
  printf '%s/.jira-integration\n' "$(jira_project_root)"
}

jira_memories_path() {
  printf '%s/.jira-memories\n' "$(jira_project_root)"
}

jira_config_value() {
  key="$1"
  config_path="${2:-$(jira_config_path)}"

  awk -F= -v key="$key" '
    $1 == key {
      sub(/^[^=]*=/, "")
      sub(/\r$/, "")
      print
      found=1
      exit
    }
    END { if (!found) exit 1 }
  ' "$config_path"
}

jira_gitignore_covers_config() {
  root="$(jira_project_root)"
  config_path="$root/.jira-integration"

  if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$root" check-ignore -q "$config_path"
    return $?
  fi

  [ -f "$root/.gitignore" ] && grep -Eq '(^|/)\.jira-integration$|^\*$|^\.\*$' "$root/.gitignore"
}

jira_warn_if_config_not_ignored() {
  if ! jira_gitignore_covers_config; then
    printf '%s\n' "Aviso: .jira-integration nao parece estar coberto por .gitignore." >&2
  fi
}

jira_init() {
  config_path="$(jira_config_path)"

  [ -f "$config_path" ] || {
    printf '%s\n' "Arquivo .jira-integration nao encontrado na raiz do projeto." >&2
    return 1
  }

  JIRA_URL="$(jira_config_value JIRA_URL "$config_path")"
  JIRA_EMAIL="$(jira_config_value JIRA_EMAIL "$config_path")"
  JIRA_API_TOKEN="$(jira_config_value JIRA_API_TOKEN "$config_path")"
  JIRA_URL="${JIRA_URL%/}"

  [ -n "$JIRA_URL" ] && [ -n "$JIRA_EMAIL" ] && [ -n "$JIRA_API_TOKEN" ] || {
    printf '%s\n' "JIRA_URL, JIRA_EMAIL e JIRA_API_TOKEN sao obrigatorios em .jira-integration." >&2
    return 1
  }

  jira_warn_if_config_not_ignored
}

jira_require_init() {
  [ -n "${JIRA_URL:-}" ] && [ -n "${JIRA_EMAIL:-}" ] && [ -n "${JIRA_API_TOKEN:-}" ] || jira_init
}

jira_curl() {
  jira_require_init || return 1

  printf 'user = "%s:%s"\n' "$JIRA_EMAIL" "$JIRA_API_TOKEN" |
    curl -sS -K - "$@"
}

jira_api_url() {
  jira_require_init || return 1

  path="$1"
  path="${path#/}"
  printf '%s/rest/api/3/%s\n' "$JIRA_URL" "$path"
}

jira_adf_text() {
  jq -n --arg text "$1" '{
    version: 1,
    type: "doc",
    content: [{
      type: "paragraph",
      content: [{type: "text", text: $text}]
    }]
  }'
}

jira_get_issue() {
  issue_key="$1"
  expand="${2:-renderedFields,names,schema}"

  jira_curl \
    -H "Accept: application/json" \
    "$(jira_api_url "issue/$issue_key?expand=$expand")"
}

jira_issue_summary() {
  issue_key="$1"

  jira_get_issue "$issue_key" |
    jq '{
      key,
      summary: .fields.summary,
      status: .fields.status.name,
      type: .fields.issuetype.name,
      priority: .fields.priority.name,
      assignee: .fields.assignee.displayName,
      labels: .fields.labels,
      description: .fields.description
    }'
}

jira_search() {
  jql="$1"
  max_results="${2:-20}"

  jira_curl -G \
    -H "Accept: application/json" \
    --data-urlencode "jql=$jql" \
    --data-urlencode "maxResults=$max_results" \
    "$(jira_api_url search)"
}

jira_get_comments() {
  issue_key="$1"

  jira_curl \
    -H "Accept: application/json" \
    "$(jira_api_url "issue/$issue_key/comment")"
}

jira_add_comment() {
  issue_key="$1"
  comment_text="$2"

  jq -n --argjson body "$(jira_adf_text "$comment_text")" '{body: $body}' |
    jira_curl -X POST \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --data @- \
      "$(jira_api_url "issue/$issue_key/comment")"
}

jira_list_transitions() {
  issue_key="$1"

  jira_curl \
    -H "Accept: application/json" \
    "$(jira_api_url "issue/$issue_key/transitions")"
}

jira_transition_names() {
  issue_key="$1"

  jira_list_transitions "$issue_key" |
    jq '.transitions[] | {id, name}'
}

jira_transition_issue() {
  issue_key="$1"
  transition_id="$2"

  jq -n --arg id "$transition_id" '{transition: {id: $id}}' |
    jira_curl -X POST \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --data @- \
      "$(jira_api_url "issue/$issue_key/transitions")"
}

jira_create_issue() {
  project_key="$1"
  summary="$2"
  issue_type="${3:-Task}"
  description="${4:-}"

  jq -n \
    --arg project "$project_key" \
    --arg summary "$summary" \
    --arg issue_type "$issue_type" \
    --argjson description "$(jira_adf_text "$description")" \
    '{
      fields: {
        project: {key: $project},
        summary: $summary,
        issuetype: {name: $issue_type},
        description: $description
      }
    }' |
    jira_curl -X POST \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --data @- \
      "$(jira_api_url issue)"
}

jira_edit_issue_file() {
  issue_key="$1"
  payload_file="$2"

  jira_curl -X PUT \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    --data @"$payload_file" \
    "$(jira_api_url "issue/$issue_key")"
}

jira_link_issues() {
  inward_issue="$1"
  outward_issue="$2"
  link_type="${3:-Relates}"

  jq -n \
    --arg type "$link_type" \
    --arg inward "$inward_issue" \
    --arg outward "$outward_issue" \
    '{
      type: {name: $type},
      inwardIssue: {key: $inward},
      outwardIssue: {key: $outward}
    }' |
    jira_curl -X POST \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --data @- \
      "$(jira_api_url issueLink)"
}

jira_fields() {
  jira_curl \
    -H "Accept: application/json" \
    "$(jira_api_url field)"
}
