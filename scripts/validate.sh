#!/usr/bin/env bash
# Repository invariants: the expected skill set, repo-level rule files, stale
# conventions, and syntax of everything executable.
#
# Spec compliance and the single-source guarantees live in check-skills.sh;
# version agreement lives in check-versions.mjs. Run all three (CI does).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CORE_SKILLS=(
  0-chain-guide
  0a-product-vision
  0b-intake
  0c-bootstrap
  1-brainstorming
  1b-visual-companion
  1c-design-intake
  1c-frontend-design
  1d-ui-mockup
  1e-concept-sync
  2-requirements-engineer
  2a-legacy-prd-migration
  2b-handoff-package
  2c-review-reconcile
  2d-release-scope
  2e-release-package
  3-architecture
  4-writing-plans
  4a-checkpoint
  4b-setup
  5-executing
  6-qa
  7-documentation
  8-delivery
  cross-review
)
OPTIONAL_SKILLS=(
  refactor-dreamer
  sonar-cli
)
EXPECTED=("${CORE_SKILLS[@]}" "${OPTIONAL_SKILLS[@]}")

fail() {
  echo "validate: $*" >&2
  exit 1
}

# ── the canonical tree holds exactly the expected skills ───────────────────
dir="$ROOT/skills"
[ -d "$dir" ] || fail "missing $dir"

count="$(find "$dir" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
[ "$count" = "${#EXPECTED[@]}" ] || fail "skills/ has $count folders, expected ${#EXPECTED[@]}"

for skill in "${EXPECTED[@]}"; do
  [ -f "$dir/$skill/SKILL.md" ] || fail "missing $dir/$skill/SKILL.md"
done

# ── repo-level rule files ──────────────────────────────────────────────────
[ -f "$ROOT/CLAUDE.md" ] || fail "missing CLAUDE.md"
grep -q 'AGENTS.md' "$ROOT/CLAUDE.md" || fail "CLAUDE.md must point to AGENTS.md"
[ -f "$ROOT/AGENTS.md" ] || fail "missing AGENTS.md"

# ── stale conventions must not come back ───────────────────────────────────
stale="$(mktemp)"
trap 'rm -f "$stale"' EXIT

if grep -R -n 'CLAUDE\.md Candidates\|CLAUDE-PROJ' "$ROOT/skills" "$ROOT/docs" >"$stale" 2>/dev/null; then
  cat "$stale" >&2
  fail "stale CLAUDE.md candidate convention found"
fi

if find "$ROOT/skills" -maxdepth 1 -type d -name autonomous-execution | grep -q .; then
  fail "autonomous-execution must not be included"
fi

if grep -R -n 'autonomous-execution' "$ROOT/skills" "$ROOT/docs" "$ROOT/README.md" >"$stale" 2>/dev/null; then
  cat "$stale" >&2
  fail "stale autonomous-execution reference found"
fi

# The two-tree layout and its per-provider installers are gone; a reference to
# either means something was reintroduced.
if grep -R -n 'install-claude\.sh\|install-codex\.sh' "$ROOT/skills" "$ROOT/docs" "$ROOT/README.md" "$ROOT/runner" >"$stale" 2>/dev/null; then
  cat "$stale" >&2
  fail "reference to a retired per-provider installer — install.sh --target replaces both"
fi

# ── schemas parse; every script is syntactically valid ─────────────────────
for schema in "$ROOT/runner/schemas/state.schema.json" \
              "$ROOT/runner/schemas/findings.schema.json" \
              "$ROOT/runner/schemas/context-manifest.schema.json"; do
  jq empty "$schema" 2>/dev/null || fail "schema does not parse: $schema"
done

while IFS= read -r sh; do
  bash -n "$sh" || fail "bash syntax error: $sh"
done < <(find "$ROOT/skills" "$ROOT/runner" "$ROOT/scripts" -name '*.sh' -type f; echo "$ROOT/install.sh")

if command -v node >/dev/null; then
  while IFS= read -r mjs; do
    node --check "$mjs" 2>/dev/null || fail "node syntax error: $mjs"
  done < <(find "$ROOT/skills" "$ROOT/runner" "$ROOT/scripts" -name '*.mjs' -type f)
fi

echo "validate: ok"
