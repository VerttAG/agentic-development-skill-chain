#!/usr/bin/env bash
#
# selfcontain-check.sh — Layer B: does this release package stand on its own?
#
# B1-B5 are the five checks 2d_release-scope defines for a scope index, applied to
# the packaged copy. B6-B8 are additions that target failures a live workspace has
# suffered: a manifest citing a PRD that never existed, and a cross-PROJ contract
# naming a project nobody packaged.
#
# Usage:
#   bash scripts/selfcontain-check.sh <package-dir> [--json <path>] [--md <path>]
# Example:
#   bash scripts/selfcontain-check.sh releases/R1-v1.0.0-rc1
#
# Checks:
#   B1  Completeness   — no feature ID appears twice in the scope index
#   B2  Resolvability  — every cited PRD path exists inside the package
#   B3  Round-trip     — every quoted US heading appears verbatim in a packaged PRD
#   B4  Leakage        — no story listed as both in-scope and excluded without PARTIAL
#   B5  Gap honesty    — every GAP row names what exists instead
#   B6  Dangling refs  — every PROJ-<X>-PRD-<N> reference resolves
#   B7  Link locality  — no markdown link resolves outside the package
#   B8  Contract closure — cross-PROJ contracts name a packaged or known project
#
# B1, B4 and B5 are reported mechanically but need a human read to close: the script
# can see a duplicate or a missing citation, not whether a judgement was right.
#
# Written for bash 3.2 (the macOS default).
#
# Exit codes:
#   0  — no findings
#   2  — at least one finding
#   64 — usage error

set -euo pipefail

PKG=""; JSON_OUT=""; MD_OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON_OUT="${2:-}"; shift 2 ;;
    --md)   MD_OUT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,36p' "$0"; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; exit 64 ;;
    *) PKG="$1"; shift ;;
  esac
done

[ -z "$PKG" ] && { echo "Usage: $0 <package-dir> [--json <path>] [--md <path>]" >&2; exit 64; }
[ -d "$PKG" ] || { echo "Not a directory: $PKG" >&2; exit 64; }
PKG="$(cd "$PKG" && pwd)"
SCOPE="$PKG/02-scope.md"
[ -f "$SCOPE" ] || { echo "No 02-scope.md in $PKG — not a release package" >&2; exit 64; }

TMP="$(mktemp -d -t selfcontain)"
trap 'rm -rf "$TMP"' EXIT
FIND_FILE="$TMP/findings"   # check \t severity \t location \t detail
: > "$FIND_FILE"
add() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$FIND_FILE"; }
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# Packaged projects, and the projects known to exist but deliberately not packaged
# (recorded by build-package.sh in the manifest, so a reference to one is classified
# rather than dangling).
( cd "$PKG/projects" && ls -1d PROJ-* 2>/dev/null || true ) | sed -E 's/^(PROJ-[0-9]+)-.*/\1/' | sort -u -V > "$TMP/packaged"
grep -m1 '^\*\*Out-of-slice' "$PKG/release-manifest.md" 2>/dev/null \
  | grep -ohE 'PROJ-[0-9]+' | sort -u -V > "$TMP/known" || true
touch "$TMP/known"

echo "Layer B · release self-containment"
echo "Package:   $PKG"
echo "Packaged:  $(tr '\n' ' ' < "$TMP/packaged")"
echo "Known-out: $(tr '\n' ' ' < "$TMP/known")"
echo

# --------------------------------------------------------- B1 · completeness

# Feature IDs are the row keys of the §1 inclusion tables: | **IC-1** | ...
grep -ohE '^\| \*\*[A-Z]{2}-[0-9]+\*\*' "$SCOPE" | grep -ohE '[A-Z]{2}-[0-9]+' | sort > "$TMP/featids"
sort "$TMP/featids" | uniq -d > "$TMP/featdupes"
FEAT_N="$(sort -u "$TMP/featids" | wc -l | tr -d ' ')"
while IFS= read -r ID; do
  [ -z "$ID" ] && continue
  add B1 warn "02-scope.md" "feature ID $ID has more than one row in the slice tables"
done < "$TMP/featdupes"

# --------------------------------------------------------- B2 · resolvability

# Explicit PRD filenames cited anywhere in the package must exist in the package.
#
# VERIFICATION.md and KNOWN-GAPS.md are excluded: naming artifacts that do NOT exist
# is precisely their purpose ("PROJ-9 has no PROJ-9-PRD-manifest.md"). Scanning them
# re-reports every Layer A finding as a broken citation.
grep -rhoE '[A-Za-z0-9_-]+\.md' "$PKG" --include='*.md' \
  --exclude='VERIFICATION.md' --exclude='KNOWN-GAPS.md' 2>/dev/null \
  | grep -E '(PRD|prd)' | sort -u > "$TMP/citedfiles" || true
while IFS= read -r FNAME; do
  [ -z "$FNAME" ] && continue
  find "$PKG" -name "$FNAME" | grep -q . && continue
  # Not packaged. Only a finding if it belongs to a packaged project.
  PROJ="$(printf '%s' "$FNAME" | grep -ohE '^PROJ-[0-9]+' || true)"
  [ -z "$PROJ" ] && continue
  grep -qx "$PROJ" "$TMP/packaged" || continue
  add B2 fail "package" "cited PRD file not present: $FNAME (its project $PROJ is packaged)"
done < "$TMP/citedfiles"

# --------------------------------------------------------- B3 · round-trip

# 2d_release-scope requires the delivering US heading to be quoted verbatim, precisely
# so a renumbering is detectable. Check each quoted "US-n: Title" against the headings
# actually present in the packaged PRDs.
grep -rhoE '^#{2,4} .*US-?[0-9]+[:.] ?[^|]*' "$PKG/projects" --include='*.md' 2>/dev/null \
  | sed -E 's/^#+ +//' | sort -u > "$TMP/realheadings" || true
grep -ohE '`P?[0-9]*-?US-?[0-9]+: [^`]+`' "$SCOPE" | tr -d '`' | sort -u > "$TMP/quoted" || true
QUOTED_N="$(wc -l < "$TMP/quoted" | tr -d ' ')"
while IFS= read -r Q; do
  [ -z "$Q" ] && continue
  TITLE="$(printf '%s' "$Q" | sed -E 's/^[^:]*: *//')"
  grep -qiF "$TITLE" "$TMP/realheadings" && continue
  # An elided quote ("US-1: …I join one shared zone queue…") cannot be round-tripped
  # by construction. That is a defect in the scope index, not in the package: the
  # verbatim heading is the redundant join key that makes a renumbering detectable,
  # and an abbreviation throws it away. Report it as its own thing.
  if printf '%s' "$Q" | grep -q '…'; then
    add B3 warn "02-scope.md" "abbreviated quote — round-trip cannot be verified: \"$Q\""
  else
    add B3 fail "02-scope.md" "quoted user story not found in any packaged PRD heading: \"$Q\""
  fi
done < "$TMP/quoted"

# --------------------------------------------------------- B4 · leakage

# A story named in §1 (in-scope) must not also appear in §2 (excluded) unless its §1
# row is marked PARTIAL — the deliberate split 2d_release-scope allows.
awk '/^# §1 · /{p=1;next} /^# §1\.5 · /{p=0} p' "$SCOPE" > "$TMP/s1"
awk '/^# §2 · /{p=1;next} /^# §3 · /{p=0} p' "$SCOPE" > "$TMP/s2"
# Only PROJECT-QUALIFIED story IDs are comparable. A bare "US-3" means a different
# story in every project, so comparing those across sections finds collisions, not
# leaks. PROJ-1's P<stage>-US<n> IDs are globally unique and can be compared.
#
# In §2 only the FIRST cell names the excluded story; later cells explain the cut and
# routinely cite in-scope stories by way of contrast ("R1's ride list is IC-20
# recent-rides only (P1-US1)"). Reading the whole row reports those as leaks.
grep -ohE 'P[0-9]+-US[0-9]+' "$TMP/s1" | sort -u > "$TMP/s1us" || true
awk -F'|' 'NF>2 {print $2}' "$TMP/s2" | grep -ohE 'P[0-9]+-US[0-9]+' | sort -u > "$TMP/s2us" || true
comm -12 "$TMP/s1us" "$TMP/s2us" > "$TMP/both" || true
while IFS= read -r U; do
  [ -z "$U" ] && continue
  if grep -F "$U" "$TMP/s1" | grep -q 'PARTIAL'; then continue; fi
  add B4 warn "02-scope.md" "$U appears in both the slice and the exclusions with no PARTIAL marking"
done < "$TMP/both"

# --------------------------------------------------------- B5 · gap honesty

# Every GAP row must say what exists instead, so it is actionable rather than an
# absence. Heuristic: the row cites a concept, a PRD, or a named owner.
# Only §1 inclusion rows whose STATUS CELL is GAP count. Matching "GAP" anywhere on a
# line also catches prose and the §1.5 decision rows, which have no status column.
awk -F'|' 'NF>3 { s=$(NF-1); gsub(/^[ \t]+|[ \t]+$/,"",s); if (s ~ /^GAP/) print }' \
  "$TMP/s1" > "$TMP/gaprows" || true
GAP_N="$(wc -l < "$TMP/gaprows" | tr -d ' ')"
while IFS= read -r ROW; do
  [ -z "$ROW" ] && continue
  printf '%s' "$ROW" | grep -qE 'concept|PROJ-[0-9]+|OP-[0-9]+|owner|Owner|inventory' && continue
  ID="$(printf '%s' "$ROW" | grep -ohE '[A-Z]{2}-[0-9]+' | head -1 || true)"
  add B5 warn "02-scope.md" "GAP row ${ID:-?} does not name what exists instead"
done < "$TMP/gaprows"

# --------------------------------------------------------- B6 · dangling references

# Every PROJ-<X>-PRD-<N> mentioned anywhere in the package must resolve to a packaged
# PRD, or belong to a project that is knowingly out of slice.
grep -rhoE 'PROJ-[0-9]+[- ]PRD-[0-9]+' "$PKG" --include='*.md' \
  --exclude='VERIFICATION.md' --exclude='KNOWN-GAPS.md' 2>/dev/null \
  | tr ' ' '-' | sort -u > "$TMP/prdrefs" || true
REF_N="$(wc -l < "$TMP/prdrefs" | tr -d ' ')"
while IFS= read -r REF; do
  [ -z "$REF" ] && continue
  RP="$(printf '%s' "$REF" | sed -E 's/^(PROJ-[0-9]+)-PRD-([0-9]+)$/\1/')"
  RN="$(printf '%s' "$REF" | sed -E 's/^(PROJ-[0-9]+)-PRD-([0-9]+)$/\2/')"
  if ! grep -qx "$RP" "$TMP/packaged"; then
    grep -qx "$RP" "$TMP/known" \
      || add B6 warn "package" "$REF names $RP, which is neither packaged nor listed as out-of-slice"
    continue
  fi
  find "$PKG/projects" -path "*$RP-*/PRDs/$RP-PRD-$RN-*.md" | grep -q . && continue
  add B6 fail "package" "$REF does not resolve — $RP is packaged but has no PRD-$RN"
done < "$TMP/prdrefs"

# --------------------------------------------------------- B7 · link locality

LINK_N=0
find "$PKG" -name '*.md' | while IFS= read -r F; do
  D="$(dirname "$F")"
  # A file with no links is normal, not an error — grep exits 1 and would abort set -e.
  { grep -ohE '\]\([^)#][^)]*\)' "$F" 2>/dev/null || true; } | sed -E 's/^\]\(//; s/\)$//' | while IFS= read -r T; do
    case "$T" in http://*|https://*|mailto:*|'#'*) continue ;; esac
    T="${T%%#*}"
    [ -z "$T" ] && continue
    if [ ! -e "$D/$T" ]; then
      add B7 fail "$(printf '%s' "$F" | sed "s|^$PKG/||")" "link target does not resolve inside the package: $T"
    fi
  done
done

# --------------------------------------------------------- B8 · contract closure

find "$PKG/projects" -name '*PRD-manifest.md' | while IFS= read -r M; do
  REL="$(printf '%s' "$M" | sed "s|^$PKG/||")"
  { awk '/^## Binding Cross-PROJ Contracts/{p=1;next} /^## /{p=0} p' "$M" \
    | grep -ohE 'PROJ-[0-9]+' || true; } | sort -u | while IFS= read -r CP; do
      [ -z "$CP" ] && continue
      grep -qx "$CP" "$TMP/packaged" && continue
      grep -qx "$CP" "$TMP/known" && continue
      add B8 fail "$REL" "binding contract names $CP, which is neither packaged nor listed as out-of-slice"
    done
done

# --------------------------------------------------------- report

TOTAL="$(wc -l < "$FIND_FILE" | tr -d ' ')"
FAILS="$(awk -F'\t' '$2=="fail"' "$FIND_FILE" | wc -l | tr -d ' ')"
WARNS="$(awk -F'\t' '$2=="warn"' "$FIND_FILE" | wc -l | tr -d ' ')"

summary() { # <check> <label> <scanned>
  local n
  n="$(awk -F'\t' -v c="$1" '$1==c' "$FIND_FILE" | wc -l | tr -d ' ')"
  if [ "$n" -eq 0 ]; then printf '| %s | %s | %s | ✅ pass |\n' "$1" "$2" "$3"
  else printf '| %s | %s | %s | ⚠️ %s finding(s) |\n' "$1" "$2" "$3" "$n"; fi
}

REPORT="$TMP/report.md"
{
  echo "| Check | What it proves | Scanned | Result |"
  echo "|---|---|---|---|"
  summary B1 "Completeness — no duplicate feature rows" "$FEAT_N feature IDs"
  summary B2 "Resolvability — cited PRD files exist in-package" "$(wc -l < "$TMP/citedfiles" | tr -d ' ') citations"
  summary B3 "Round-trip — quoted US headings exist verbatim" "$QUOTED_N quoted headings"
  summary B4 "Leakage — nothing both in-scope and excluded" "$(wc -l < "$TMP/both" | tr -d ' ') overlaps"
  summary B5 "Gap honesty — GAP rows say what exists instead" "$GAP_N GAP rows"
  summary B6 "Dangling references — every PRD ID resolves" "$REF_N distinct references"
  summary B7 "Link locality — no link leaves the package" "$(find "$PKG" -name '*.md' | wc -l | tr -d ' ') files"
  summary B8 "Contract closure — cross-PROJ contracts land" "$(find "$PKG/projects" -name '*PRD-manifest.md' | wc -l | tr -d ' ') manifests"
} > "$REPORT"

cat "$REPORT"
echo
if [ "$TOTAL" -gt 0 ]; then
  printf '%-4s %-5s %s\n' "ID" "SEV" "LOCATION — DETAIL"
  printf '%-4s %-5s %s\n' "----" "----" "------------------"
  awk -F'\t' '{printf "%-4s %-5s %s — %s\n",$1,$2,$3,$4}' "$FIND_FILE"
  echo
fi
echo "Findings: $FAILS fail, $WARNS warn"

if [ -n "$MD_OUT" ]; then
  {
    echo "# Verification — Layer B (self-containment)"
    echo
    echo "Run $(date +%Y-%m-%d) by \`selfcontain-check.sh\` against \`$(basename "$PKG")\`."
    echo
    cat "$REPORT"
    echo
    if [ "$TOTAL" -gt 0 ]; then
      echo "## Findings"
      echo
      echo "| Check | Severity | Location | Detail |"
      echo "|---|---|---|---|"
      awk -F'\t' '{printf "| %s | %s | `%s` | %s |\n",$1,$2,$3,$4}' "$FIND_FILE"
    else
      echo "No findings."
    fi
    echo
    echo "**B1, B4 and B5 need a human read to close** — the script sees a duplicate or a"
    echo "missing citation, not whether a judgement was right."
  } > "$MD_OUT"
  echo "Markdown: $MD_OUT"
fi

if [ -n "$JSON_OUT" ]; then
  {
    printf '{\n  "layer": "B",\n  "package": "%s",\n  "findings": [\n' "$(json_escape "$(basename "$PKG")")"
    first=1
    while IFS="$(printf '\t')" read -r c s l d; do
      [ -z "$c" ] && continue
      [ $first -eq 1 ] && first=0 || printf ',\n'
      printf '    {"check": "%s", "severity": "%s", "location": "%s", "detail": "%s"}' \
        "$c" "$s" "$(json_escape "$l")" "$(json_escape "$d")"
    done < "$FIND_FILE"
    printf '\n  ]\n}\n'
  } > "$JSON_OUT"
  echo "JSON: $JSON_OUT"
fi

[ "$TOTAL" -eq 0 ] && exit 0
exit 2
