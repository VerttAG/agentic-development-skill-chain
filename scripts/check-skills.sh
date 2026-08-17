#!/usr/bin/env bash
# Spec + structure gate for the canonical skills/ tree.
#
# Checks the Agent Skills spec (https://agentskills.io/specification) plus the
# invariants this repo adds on top of it. Runs before the test suite in CI so
# drift surfaces as a one-line error rather than a stack trace.
#
# Bash 3.2 compatible. Requires nothing but coreutils.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS="$ROOT/skills"
FAIL=0

# The spec's complete frontmatter field set. Anything else hard-fails
# claude.ai upload, the Skills API, and package_skill.py.
SPEC_FIELDS="name description license compatibility metadata allowed-tools"

# Per-skill description cap, and the collection budget. Codex renders the
# startup skill list into ~2% of the context window or 8000 characters and
# silently omits skills past that — so the total is a real constraint.
DESC_MAX=250
DESC_BUDGET=8000

bad()  { echo "FAIL  $*" >&2; FAIL=1; }
warn() { echo "warn  $*" >&2; }
ok()   { echo "ok    $*"; }

[ -d "$SKILLS" ] || { echo "check-skills: $SKILLS not found" >&2; exit 1; }

# ── 1. no second skill tree ────────────────────────────────────────────────
for stale in "$ROOT/claude" "$ROOT/codex"; do
  [ -d "$stale" ] && bad "a second skill tree exists at ${stale#$ROOT/} — skills/ is the only source"
done

# ── 2. per-skill spec compliance ───────────────────────────────────────────
TOTAL_DESC=0
COUNT=0
for dir in "$SKILLS"/*/; do
  name="$(basename "$dir")"
  file="$dir/SKILL.md"
  COUNT=$((COUNT + 1))

  [ -f "$file" ] || { bad "$name: no SKILL.md"; continue; }
  head -n 1 "$file" | grep -qx -- '---' || { bad "$name: SKILL.md does not open with YAML frontmatter"; continue; }

  # name: must exist, match the directory, and satisfy the spec charset
  fm_name="$(sed -n 's/^name: *//p' "$file" | head -1 | tr -d '"'"'"'')"
  [ -n "$fm_name" ] || bad "$name: no name field"
  [ "$fm_name" = "$name" ] || bad "$name: frontmatter name is '$fm_name' — the spec requires it to match the directory"
  echo "$name" | grep -qE '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$' || bad "$name: not lowercase alphanumeric + hyphens, or starts/ends with a hyphen"
  case "$name" in *--*) bad "$name: consecutive hyphens are not allowed" ;; esac
  [ ${#name} -le 64 ] || bad "$name: longer than 64 characters"

  # description: must exist and stay inside the per-skill cap
  desc="$(awk '/^---$/{n++; next} n==1' "$file" \
        | awk '/^description:/{f=1} f && !/^(license|compatibility|metadata|allowed-tools|name):/{print} /^(license|compatibility|metadata|allowed-tools|name):/{if(f)exit}' \
        | sed 's/^description: *//' | tr '\n' ' ' | sed 's/^ *//; s/ *$//' | tr -d '"')"
  if [ -z "$desc" ]; then
    bad "$name: no description field"
  else
    len=${#desc}
    TOTAL_DESC=$((TOTAL_DESC + len))
    [ "$len" -le "$DESC_MAX" ] || bad "$name: description is $len chars (max $DESC_MAX)"
  fi

  # frontmatter keys must all be spec fields
  for key in $(awk '/^---$/{n++; next} n==1 && /^[a-zA-Z][a-zA-Z-]*:/{sub(":.*","",$1); print $1}' "$file"); do
    echo " $SPEC_FIELDS " | grep -q " $key " || bad "$name: '$key' is not an Agent Skills spec field ($SPEC_FIELDS)"
  done

  # body length is a spec recommendation, not a hard rule
  lines=$(wc -l < "$file" | tr -d ' ')
  [ "$lines" -le 500 ] || warn "$name: SKILL.md is $lines lines (spec recommends under 500 — move detail to references/ or assets/)"
done
ok "$COUNT skills checked"

# ── 3. collection description budget ───────────────────────────────────────
if [ "$TOTAL_DESC" -gt "$DESC_BUDGET" ]; then
  bad "descriptions total $TOTAL_DESC chars — over the $DESC_BUDGET budget; hosts will silently omit skills from the startup list"
else
  ok "description budget: $TOTAL_DESC / $DESC_BUDGET chars"
fi

# ── 4. no duplicated helper scripts ────────────────────────────────────────
# The pre-2.0 layout kept byte-identical copies of these across two trees.
# One physical copy per helper now; siblings resolve it with ../<skill>/...
dupes="$(find "$SKILLS" -type f \( -name '*.sh' -o -name '*.mjs' \) -exec basename {} \; | sort | uniq -d)"
if [ -n "$dupes" ]; then
  for d in $dupes; do
    bad "helper '$d' exists more than once: $(find "$SKILLS" -name "$d" | sed "s#$ROOT/##" | tr '\n' ' ')"
  done
else
  ok "no duplicated helper scripts"
fi

# ── 5. no host-specific skill-home paths in prose ──────────────────────────
leaks="$(grep -rln '~/\.claude/skills\|~/\.codex/skills' "$SKILLS" --include='*.md' 2>/dev/null || true)"
if [ -n "$leaks" ]; then
  for l in $leaks; do bad "${l#$ROOT/} hardcodes a host skill home — use ../<skill>/... instead"; done
else
  ok "no hardcoded host skill homes in skill prose"
fi

# ── 6. relative references resolve ─────────────────────────────────────────
missing=0
for dir in "$SKILLS"/*/; do
  name="$(basename "$dir")"
  for ref in $(grep -oh '`\.\./[0-9a-z-]*/[a-zA-Z0-9/._-]*`' "$dir"/*.md 2>/dev/null | tr -d '`' | sort -u); do
    [ -e "$SKILLS/${ref#../}" ] || { bad "$name: sibling reference '$ref' does not resolve"; missing=1; }
  done
  for ref in $(grep -oh '](\(assets\|references\)/[a-zA-Z0-9/._-]*)' "$dir"/*.md 2>/dev/null | sed 's/^](//; s/)$//' | sort -u); do
    [ -e "$dir/$ref" ] || { bad "$name: link '$ref' does not resolve"; missing=1; }
  done
done
[ "$missing" -eq 0 ] && ok "all sibling and asset references resolve"

# ── 7. no editor/OS junk ───────────────────────────────────────────────────
junk="$(find "$SKILLS" -name '.DS_Store' -o -name 'Thumbs.db' | head -5)"
[ -n "$junk" ] && warn "OS metadata present in skills/ (gitignored, and install.sh strips it): $(echo "$junk" | tr '\n' ' ')"

# ── 8. manifests point at the canonical tree ───────────────────────────────
for m in "$ROOT/.claude-plugin/plugin.json" "$ROOT/.claude-plugin/marketplace.json" "$ROOT/.codex-plugin/plugin.json" "$ROOT/gemini-extension.json"; do
  [ -f "$m" ] || bad "missing manifest ${m#$ROOT/}"
  command -v jq >/dev/null 2>&1 && { jq empty "$m" 2>/dev/null || bad "${m#$ROOT/} does not parse as JSON"; }
done
if command -v jq >/dev/null 2>&1 && [ -f "$ROOT/.codex-plugin/plugin.json" ]; then
  s=$(jq -r '.skills // empty' "$ROOT/.codex-plugin/plugin.json")
  [ "$s" = "./skills/" ] || bad ".codex-plugin/plugin.json skills must be \"./skills/\" (found: '${s:-unset}')"
fi
[ "$FAIL" -eq 0 ] && ok "manifests present and well-formed"

echo
if [ "$FAIL" -eq 0 ]; then echo "check-skills: ok"; else echo "check-skills: FAILED" >&2; fi
exit "$FAIL"
