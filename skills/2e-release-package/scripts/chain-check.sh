#!/usr/bin/env bash
#
# chain-check.sh — Layer A: chain integrity of every PROJ in a release slice.
#
# Replays the discovery-track probes of 0-chain-guide (steps 1 and 2) against each
# PROJ that the release slice draws on, and reports every PROJ whose chain has a
# hole. Findings name the SOURCE path, because that is where a fix must land — the
# release package is derived and is never hand-edited.
#
# Usage:
#   bash scripts/chain-check.sh <release-dir> [--json <path>] [--repo <path>]
# Example:
#   bash scripts/chain-check.sh specs/_releases/R1-selbstzahler-pilot
#
# <release-dir> must contain an R<N>-scope.md. The in-slice PROJ set is derived
# from that file's "# §1 ·" (the slice) and "# §3 ·" (dependency closure) sections
# — never from a hand-authored list, so it cannot disagree with the scope index.
#
# Checks:
#   A1  concept file exists
#   A2  concept ## Status reads as approved
#   A3  at least one PRD (2_PRDs/ current or 3_PRDs/ legacy)
#   A4  PRD manifest exists
#   A5  no unmarked superseded PRD directory inside the PRD folder
#   A6  every PRD carries at least one v2 UC or legacy user-story heading
#   A7  handoff freshness — the newest handoff RUN was produced after the latest PRD commit
#       (measured from the run directory's birth, so editing an old run cannot fake freshness)
#
# Deliberately NOT checked: architecture, wave plans, state.json. This repo is on
# the discovery track, where a PROJ is complete at step 2 (0-chain-guide).
#
# Written for bash 3.2 (the macOS default): no mapfile, no associative arrays.
#
# Exit codes:
#   0  — every in-slice PROJ passes
#   2  — at least one finding (see the table and the JSON report)
#   64 — usage error

set -euo pipefail

RELEASE_DIR=""
JSON_OUT=""
REPO_ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON_OUT="${2:-}"; shift 2 ;;
    --repo) REPO_ROOT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; exit 64 ;;
    *) RELEASE_DIR="$1"; shift ;;
  esac
done

[ -z "$RELEASE_DIR" ] && { echo "Usage: $0 <release-dir> [--json <path>] [--repo <path>]" >&2; exit 64; }
[ -d "$RELEASE_DIR" ] || { echo "Not a directory: $RELEASE_DIR" >&2; exit 64; }

if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git -C "$RELEASE_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -z "$REPO_ROOT" ] && { echo "Not inside a git repo; pass --repo <path>" >&2; exit 64; }
fi

SCOPE_FILE="$(find "$RELEASE_DIR" -maxdepth 1 -name 'R*-scope.md' | head -1)"
[ -z "$SCOPE_FILE" ] && { echo "No R<N>-scope.md in $RELEASE_DIR" >&2; exit 64; }

# ---------------------------------------------------------------- slice resolution

# In-slice = every PROJ cited in the scope index's §1 (inclusions) or §3 (dependency
# closure). §2 is the exclusion register: the PROJs there are in-slice too — that is
# precisely why their later-phase stories have to be named as excluded.
section() { # <file> <start-regex> <end-regex>
  awk -v s="$2" -v e="$3" '$0 ~ s {p=1; next} $0 ~ e {p=0} p' "$1"
}

PROJS="$(
  { section "$SCOPE_FILE" '^# §1 · ' '^# §1\.5 · '
    section "$SCOPE_FILE" '^# §3 · ' '^# §4 · '
  } | grep -ohE 'PROJ-[0-9]+' | sort -u -V
)"

[ -z "$PROJS" ] && { echo "Resolved an empty slice from $SCOPE_FILE — check its §1/§3 headings" >&2; exit 64; }

# ---------------------------------------------------------------- helpers

# Findings accumulate in a temp file rather than an array: bash 3.2 handles empty
# arrays badly under `set -u`.
FIND_FILE="$(mktemp -t chaincheck)"
trap 'rm -f "$FIND_FILE" "$FIND_FILE.prds"' EXIT

add() { # <id> <proj> <check> <severity> <source_path> <detail>
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$FIND_FILE"
}

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

proj_dir() { # <PROJ-N> -> repo-relative dir, or empty
  ( cd "$REPO_ROOT" && find specs -maxdepth 1 -type d -name "$1-*" | head -1 )
}

prd_dir() { # <proj-dir> -> repo-relative PRD dir, or empty
  local p
  for p in 2_PRDs 3_PRDs; do   # current layout first, legacy second — both are supported
    [ -d "$REPO_ROOT/$1/$p" ] && { printf '%s' "$1/$p"; return 0; }
  done
  return 0
}

# A PRD is a spec document, not a review log or an index. PROJ-1 does not use the
# PROJ-<N>-PRD-<n>- convention (its files are 4_delivery-phase-1-product-prd.md), so
# select by exclusion rather than by pattern.
prd_files() { # <prd-dir> -> repo-relative PRD file paths, one per line
  local f b
  ( cd "$REPO_ROOT" && find "$1" -maxdepth 1 -name '*.md' | sort ) | while IFS= read -r f; do
    b="$(basename "$f")"
    case "$b" in
      *manifest*|*review*|*changelog*|linear-import*|README*|*analysis*|*agenda*|*summary*|*open-decisions*) continue ;;
    esac
    printf '%s\n' "$f"
  done
}

# ---------------------------------------------------------------- checks

for P in $PROJS; do
  PDIR="$(proj_dir "$P")"
  if [ -z "$PDIR" ]; then
    add A0 "$P" "proj-dir-missing" fail "specs/$P-*" "no PROJ directory found in specs/"
    continue
  fi

  # A1 · concept present
  CONCEPT=""
  if [ -d "$REPO_ROOT/$PDIR/1_brainstorm" ]; then
    CONCEPT="$( cd "$REPO_ROOT" && find "$PDIR/1_brainstorm" -maxdepth 1 -name "$P-concept.md" | head -1 )"
  fi
  if [ -z "$CONCEPT" ]; then
    add A1 "$P" "concept-missing" fail "$PDIR/1_brainstorm/" "no $P-concept.md"
  else
    # A2 · concept approved. Three outcomes: approved, draft (fail), anything else
    # (needs a human read — several concepts here carry bespoke status prose).
    # Test "approved" FIRST: an approved concept may still say "requirements may be
    # drafted", and matching draft first would fail it wrongly.
    STATUS="$( cd "$REPO_ROOT" && awk '/^## Status/{f=1;next} f&&NF{print;exit}' "$CONCEPT" | tr -d '\r' )"
    if [ -z "$STATUS" ]; then
      add A2 "$P" "concept-status" warn "$CONCEPT" "no ## Status section"
    elif printf '%s' "$STATUS" | grep -qi 'approved'; then
      : # approved
    elif printf '%s' "$STATUS" | grep -qi 'draft'; then
      add A2 "$P" "concept-status" fail "$CONCEPT" "status reads as draft: $(printf '%s' "$STATUS" | cut -c1-60)"
    else
      add A2 "$P" "concept-status" warn "$CONCEPT" "needs-manual-read: $(printf '%s' "$STATUS" | cut -c1-60)"
    fi
  fi

  # A3 · PRDs present
  PRDDIR="$(prd_dir "$PDIR")"
  if [ -z "$PRDDIR" ]; then
    add A3 "$P" "prds-missing" fail "$PDIR/" "no 2_PRDs/ or 3_PRDs/ directory"
    continue
  fi
  prd_files "$PRDDIR" > "$FIND_FILE.prds"
  PRD_COUNT="$(wc -l < "$FIND_FILE.prds" | tr -d ' ')"
  if [ "$PRD_COUNT" -eq 0 ]; then
    add A3 "$P" "prds-missing" fail "$PRDDIR/" "PRD directory holds no PRD documents"
    continue
  fi

  # A4 · manifest present
  if [ ! -f "$REPO_ROOT/$PRDDIR/$P-PRD-manifest.md" ]; then
    add A4 "$P" "manifest-missing" fail "$PRDDIR/" "no $P-PRD-manifest.md ($PRD_COUNT PRDs present)"
  fi

  # A5 · superseded PRDs still inside the live PRD folder. An underscore-prefixed
  # subdirectory is the repo's archive convention. Naming it in the manifest makes it
  # documented, not absent: a glob over the PRD folder still reads a contradictory
  # model, so a named archive is a warning and an unnamed one is a failure.
  ( cd "$REPO_ROOT" && find "$PRDDIR" -mindepth 1 -maxdepth 1 -type d -name '_*' | sort ) | while IFS= read -r ARCH; do
    [ -z "$ARCH" ] && continue
    AB="$(basename "$ARCH")"
    N="$( cd "$REPO_ROOT" && find "$ARCH" -name '*.md' | wc -l | tr -d ' ' )"
    if [ -f "$REPO_ROOT/$PRDDIR/$P-PRD-manifest.md" ] && grep -qF "$AB" "$REPO_ROOT/$PRDDIR/$P-PRD-manifest.md"; then
      add A5 "$P" "superseded-prds" warn "$ARCH/" "archived PRD dir inside the live PRD folder; named in the manifest ($N files)"
    else
      add A5 "$P" "superseded-prds" fail "$ARCH/" "archived PRD dir inside the live PRD folder, unnamed in the manifest ($N files)"
    fi
  done

  # A6 · every PRD carries at least one v2 UC or legacy user story.
  while IFS= read -r F; do
    [ -z "$F" ] && continue
    if ! grep -qE '^### UC-[a-z0-9-]+-[0-9]{2} — As an? |^#{2,4} .*US-?[0-9]+' "$REPO_ROOT/$F"; then
      add A6 "$P" "prd-no-user-story" warn "$F" "no UC or legacy US heading found"
    fi
  done < "$FIND_FILE.prds"

  # A7 · handoff freshness. Only meaningful where a handoff exists at all.
  HDIR=""
  for h in 2b_handoff 8_handoff; do
    [ -d "$REPO_ROOT/$PDIR/$h" ] && { HDIR="$PDIR/$h"; break; }
  done
  if [ -n "$HDIR" ]; then
    # "When was a handoff run last PRODUCED", not "when was anything under 8_handoff/ last
    # touched". Those differ, and the difference is load-bearing: editing any historical run —
    # a superseded marker, a pointer, a typo — would otherwise mark every handoff fresh and
    # silence this check without a handoff having been generated. Observed doing exactly that.
    #
    # The newest run directory's BIRTH commit is the honest signal: it is written once, at
    # generation, and later edits inside the run cannot move it.
    NEWEST_RUN="$( cd "$REPO_ROOT" && find "$HDIR" -maxdepth 1 -type d -name '*handoff*' 2>/dev/null | sort | tail -1 )"
    if [ -n "$NEWEST_RUN" ]; then
      LAST_HANDOFF="$( cd "$REPO_ROOT" && git log --diff-filter=A --format=%ct -- "$NEWEST_RUN" 2>/dev/null | tail -1 || true )"
    else
      LAST_HANDOFF=""
    fi
    # Fall back to the old proxy only where the run has no recorded birth (unstaged, or a
    # layout this rule does not know). A weaker check beats none.
    [ -z "$LAST_HANDOFF" ] && LAST_HANDOFF="$( cd "$REPO_ROOT" && git log -1 --format=%ct -- "$HDIR" 2>/dev/null || true )"
    LAST_PRD="$( cd "$REPO_ROOT" && git log -1 --format=%ct -- "$PRDDIR" 2>/dev/null || true )"
    LAST_HANDOFF="${LAST_HANDOFF:-0}"; LAST_PRD="${LAST_PRD:-0}"
    if [ "$LAST_HANDOFF" -gt 0 ] && [ "$LAST_PRD" -gt "$LAST_HANDOFF" ]; then
      add A7 "$P" "handoff-stale" warn "$HDIR/" \
        "PRDs changed $(( (LAST_PRD - LAST_HANDOFF) / 86400 ))d after the newest handoff run"
    fi
  fi
done

# ---------------------------------------------------------------- report

TOTAL="$(wc -l < "$FIND_FILE" | tr -d ' ')"
FAILS="$(awk -F'\t' '$4=="fail"' "$FIND_FILE" | wc -l | tr -d ' ')"
WARNS="$(awk -F'\t' '$4=="warn"' "$FIND_FILE" | wc -l | tr -d ' ')"

echo "Layer A · chain integrity"
echo "Release:  $RELEASE_DIR"
echo "Scope:    $SCOPE_FILE"
echo "In-slice: $(printf '%s ' $PROJS)"
echo
if [ "$TOTAL" -eq 0 ]; then
  echo "No findings."
else
  awk -F'\t' 'BEGIN{printf "%-4s %-9s %-20s %-5s %s\n","ID","PROJ","CHECK","SEV","SOURCE — DETAIL"
                    printf "%-4s %-9s %-20s %-5s %s\n","----","-------","------------------","----","---------------"}
              {printf "%-4s %-9s %-20s %-5s %s — %s\n",$1,$2,$3,$4,$5,$6}' "$FIND_FILE"
fi
echo
echo "Findings: $FAILS fail, $WARNS warn"

if [ -n "$JSON_OUT" ]; then
  {
    printf '{\n  "layer": "A",\n  "release": "%s",\n' "$(json_escape "$RELEASE_DIR")"
    printf '  "in_slice": ['
    first=1
    for P in $PROJS; do [ $first -eq 1 ] && first=0 || printf ', '; printf '"%s"' "$P"; done
    printf '],\n  "findings": [\n'
    first=1
    while IFS="$(printf '\t')" read -r id proj check sev src detail; do
      [ -z "$id" ] && continue
      [ $first -eq 1 ] && first=0 || printf ',\n'
      printf '    {"id": "%s", "proj": "%s", "check": "%s", "severity": "%s", "source_path": "%s", "detail": "%s"}' \
        "$id" "$proj" "$check" "$sev" "$(json_escape "$src")" "$(json_escape "$detail")"
    done < "$FIND_FILE"
    printf '\n  ]\n}\n'
  } > "$JSON_OUT"
  echo "JSON: $JSON_OUT"
fi

[ "$TOTAL" -eq 0 ] && exit 0
exit 2
