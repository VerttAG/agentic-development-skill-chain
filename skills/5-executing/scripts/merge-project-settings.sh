#!/usr/bin/env bash
# Merge the execution permissions template into the project's .claude/settings.json.
# Idempotent: re-running adds nothing new if template entries are already present.
# Deny list is additive too — never removes existing deny rules.
#
# Usage: bash scripts/merge-project-settings.sh [--dry-run]
#
# Relies on jq. Exits non-zero if jq is missing, template is missing, or merge fails.

set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

PROJECT_SETTINGS=".claude/settings.json"

# Resolve the template relative to this script first (works when the script is
# still inside the installed 5-executing skill), then fall back to the known
# skill homes for the case where only this file was copied into the project.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
resolve_template() {
  local p
  for p in "$SCRIPT_DIR/../references/project-settings-template.json" \
           ${SKILL_CHAIN_HOME:+"$SKILL_CHAIN_HOME/5-executing/references/project-settings-template.json"} \
           "$HOME/.agents/skills/5-executing/references/project-settings-template.json" \
           "$HOME/.claude/skills/5-executing/references/project-settings-template.json" \
           "$HOME/.codex/skills/5-executing/references/project-settings-template.json"; do
    [ -f "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}
TEMPLATE="${CLAUDE_EXEC_TEMPLATE:-$(resolve_template || true)}"

command -v jq >/dev/null 2>&1 || { echo "merge-project-settings: jq not installed" >&2; exit 2; }
[[ -f "$TEMPLATE" ]] || { echo "merge-project-settings: template not found at $TEMPLATE" >&2; exit 2; }

mkdir -p "$(dirname "$PROJECT_SETTINGS")"
[[ -f "$PROJECT_SETTINGS" ]] || echo '{}' > "$PROJECT_SETTINGS"

# Strip "_comment" + "$schema" from template, then union allow/deny arrays.
# defaultMode: project wins if explicitly set, otherwise template supplies it.
# hooks: per event, template entries are appended once (structural dedupe) —
# existing project hooks are never removed. env: project values win.
MERGED=$(jq -s '
  def union_unique: (.[0] // []) + (.[1] // []) | unique;
  (.[0] | del(._comment, ."$schema")) as $tpl
  | .[1] as $proj
  | $proj
    | .permissions.allow = (($proj.permissions.allow // []) + ($tpl.permissions.allow // []) | unique)
    | .permissions.deny  = (($proj.permissions.deny  // []) + ($tpl.permissions.deny  // []) | unique)
    | (if ($proj.permissions.defaultMode // null) == null and ($tpl.permissions.defaultMode // null) != null
       then .permissions.defaultMode = $tpl.permissions.defaultMode
       else . end)
    | .hooks = (
        ($proj.hooks // {}) as $ph
        | $ph + (($tpl.hooks // {}) | with_entries(.value = ((($ph[.key] // []) + .value) | unique)))
      )
    | .env = (($tpl.env // {}) + ($proj.env // {}))
    | (if .hooks == {} then del(.hooks) else . end)
    | (if .env == {} then del(.env) else . end)
' "$TEMPLATE" "$PROJECT_SETTINGS")

if [[ "$DRY_RUN" == "1" ]]; then
  echo "$MERGED" | jq .
  exit 0
fi

TMP=$(mktemp)
echo "$MERGED" | jq . > "$TMP"
mv "$TMP" "$PROJECT_SETTINGS"
echo "merge-project-settings: .claude/settings.json updated ($(jq '.permissions.allow | length' "$PROJECT_SETTINGS") allow, $(jq '.permissions.deny | length' "$PROJECT_SETTINGS") deny)"
