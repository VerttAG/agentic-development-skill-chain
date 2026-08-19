#!/usr/bin/env bash
#
# build-package.sh — assemble a standalone, immutable specs release package.
#
# Copies every specification the release slice draws on into one folder that a
# reader can consume without the rest of the repository, pins the commit each file
# came from, and rewrites internal links so nothing points outside the package.
#
# Usage:
#   bash scripts/build-package.sh <release-dir> <version> [--out <dir>] [--repo <path>]
# Example:
#   bash scripts/build-package.sh specs/_releases/R1-selbstzahler-pilot v1.0.0-rc1
#
# The in-slice PROJ set is DERIVED from <release-dir>/R<N>-scope.md — its "# §1 ·"
# (the slice) and "# §3 ·" (dependency closure) sections. There is no hand-authored
# slice declaration, so nothing can disagree with the scope index.
#
# Packages are immutable: the script refuses to write into an existing directory.
#
# Written for bash 3.2 (the macOS default).
#
# Exit codes:
#   0  — package written
#   2  — package written, but with warnings (unresolved link rewrites)
#   64 — usage error, or target already exists

set -euo pipefail

RELEASE_DIR=""; VERSION=""; OUT_DIR=""; REPO_ROOT=""
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --out)  OUT_DIR="${2:-}"; shift 2 ;;
    --repo) REPO_ROOT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; exit 64 ;;
    *) if [ -z "$RELEASE_DIR" ]; then RELEASE_DIR="$1"; else VERSION="$1"; fi; shift ;;
  esac
done

if [ -z "$RELEASE_DIR" ] || [ -z "$VERSION" ]; then
  echo "Usage: $0 <release-dir> <version> [--out <dir>] [--repo <path>]" >&2; exit 64
fi
[ -d "$RELEASE_DIR" ] || { echo "Not a directory: $RELEASE_DIR" >&2; exit 64; }

if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git -C "$RELEASE_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -z "$REPO_ROOT" ] && { echo "Not inside a git repo; pass --repo <path>" >&2; exit 64; }
fi
[ -z "$OUT_DIR" ] && OUT_DIR="$REPO_ROOT/releases"

SCOPE_FILE="$(find "$RELEASE_DIR" -maxdepth 1 -name 'R*-scope.md' | head -1)"
[ -z "$SCOPE_FILE" ] && { echo "No R<N>-scope.md in $RELEASE_DIR" >&2; exit 64; }
RELEASE="$(basename "$SCOPE_FILE" | sed -E 's/^(R[0-9]+)-scope\.md$/\1/')"

PKG_NAME="$RELEASE-$VERSION"
PKG="$OUT_DIR/$PKG_NAME"
[ -e "$PKG" ] && { echo "Refusing to overwrite an existing package: $PKG" >&2
                   echo "Packages are immutable — build a new version instead." >&2; exit 64; }

BUILD_DATE="$(date +%Y-%m-%d)"
REPO_HEAD="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"

WARN=0
TMP="$(mktemp -d -t buildpkg)"
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------- slice resolution

section() { awk -v s="$2" -v e="$3" '$0 ~ s {p=1; next} $0 ~ e {p=0} p' "$1"; }

IN_SLICE="$(
  { section "$SCOPE_FILE" '^# §1 · ' '^# §1\.5 · '
    section "$SCOPE_FILE" '^# §3 · ' '^# §4 · '
  } | grep -ohE 'PROJ-[0-9]+' | sort -u -V
)"
[ -z "$IN_SLICE" ] && { echo "Resolved an empty slice from $SCOPE_FILE" >&2; exit 64; }

ALL_PROJS="$( cd "$REPO_ROOT" && find specs -maxdepth 1 -type d -name 'PROJ-*' \
              | sed -E 's|specs/(PROJ-[0-9]+)-.*|\1|' | sort -u -V )"
OUT_OF_SLICE=""
for P in $ALL_PROJS; do
  echo "$IN_SLICE" | grep -qx "$P" || OUT_OF_SLICE="$OUT_OF_SLICE $P"
done
OUT_OF_SLICE="$(echo "$OUT_OF_SLICE" | sed 's/^ //')"

echo "Release:  $RELEASE"
echo "Version:  $VERSION"
echo "Package:  $PKG"
echo "HEAD:     $REPO_HEAD ($BRANCH)"
echo "In-slice: $(printf '%s ' $IN_SLICE)"
echo

mkdir -p "$PKG/projects"
: > "$TMP/artifacts"   # package_path \t source_path \t note
: > "$TMP/snapshot"    # source_path \t commit

record() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$TMP/artifacts"
           SHA="$( cd "$REPO_ROOT" && git log -1 --format=%h -- "$2" 2>/dev/null || true )"
           printf '%s\t%s\n' "$2" "${SHA:-uncommitted}" >> "$TMP/snapshot"; }

rel() { printf '%s' "${1#$REPO_ROOT/}"; }   # absolute -> repo-relative

# ---------------------------------------------------------------- frozen index files

# Map the release working documents onto stable, reader-ordered package names.
freeze() { # <glob> <package-name> <note>
  local src n
  # An ambiguous glob is a build failure, not a coin toss. `head -1` silently picked
  # one of several matches, and the file it picked was copied in under a name that
  # promises different content — a release folder gained an `R1-review-findings-*.md`
  # and the package's frozen change narrative silently became that intake instead.
  # The dangling links were caught by B7; the substituted content was not caught by
  # anything, because both files exist and both are valid markdown.
  n="$(find "$RELEASE_DIR" -maxdepth 1 -name "$1" | wc -l | tr -d " ")"
  if [ "$n" -gt 1 ]; then
    echo "Ambiguous freeze pattern [$1] matched $n files in $RELEASE_DIR:" >&2
    find "$RELEASE_DIR" -maxdepth 1 -name "$1" | while IFS= read -r amb; do echo "  $amb" >&2; done
    echo "Exactly one file may match, or the package silently freezes the wrong one." >&2
    echo "Rename the others so they fall outside the pattern." >&2
    exit 64
  fi
  src="$(find "$RELEASE_DIR" -maxdepth 1 -name "$1" | head -1)"
  [ -z "$src" ] && return 0
  cp "$src" "$PKG/$2"
  record "$2" "$(rel "$src")" "$3"
  printf '%s\n' "$(basename "$src")|$2" >> "$TMP/renames"
}

: > "$TMP/renames"
freeze 'release-*-definition.md' '01-definition.md'      'Release charter — intent'
freeze 'R*-scope.md'             '02-scope.md'           'AUTHORITY on release membership'
freeze 'R*-forward-compat.md'    '03-forward-compat.md'  'Forward-compatibility obligations'
freeze 'R*-gaps.md'              '04-gaps-at-release.md' 'Ranked gap register at build time'
freeze 'R*-review-*.md'          '05-review-notes.md'    'Change narrative from the last scope pass'

# ---------------------------------------------------------------- project payload

PRD_TOTAL=0; US_TOTAL=0; PROJ_TOTAL=0

for P in $IN_SLICE; do
  PDIR="$( cd "$REPO_ROOT" && find specs -maxdepth 1 -type d -name "$P-*" | head -1 )"
  [ -z "$PDIR" ] && { echo "  ! $P has no directory — skipped" >&2; WARN=1; continue; }
  PNAME="$(basename "$PDIR")"

  PRDDIR=""
  for d in 2_PRDs 3_PRDs; do
    [ -d "$REPO_ROOT/$PDIR/$d" ] && { PRDDIR="$PDIR/$d"; break; }
  done

  mkdir -p "$PKG/projects/$PNAME/PRDs"
  PROJ_TOTAL=$((PROJ_TOTAL+1))

  # Source basenames are preserved throughout the payload. The specs cite each other
  # by filename constantly ("see PROJ-18-PRD-manifest.md"), so renaming files here
  # would break every one of those references — and the resolvability check would be
  # right to fail it.

  # concept
  C="$REPO_ROOT/$PDIR/1_brainstorm/$P-concept.md"
  if [ -f "$C" ]; then
    cp "$C" "$PKG/projects/$PNAME/$P-concept.md"
    record "projects/$PNAME/$P-concept.md" "$PDIR/1_brainstorm/$P-concept.md" "Approved concept"
  fi

  [ -z "$PRDDIR" ] && { echo "  ! $P has no PRD directory" >&2; WARN=1; continue; }

  # manifest
  if [ -f "$REPO_ROOT/$PRDDIR/$P-PRD-manifest.md" ]; then
    cp "$REPO_ROOT/$PRDDIR/$P-PRD-manifest.md" "$PKG/projects/$PNAME/$P-PRD-manifest.md"
    record "projects/$PNAME/$P-PRD-manifest.md" "$PRDDIR/$P-PRD-manifest.md" "PRD manifest"
  fi

  # linear import, where one exists
  if [ -f "$REPO_ROOT/$PRDDIR/linear-import.md" ]; then
    cp "$REPO_ROOT/$PRDDIR/linear-import.md" "$PKG/projects/$PNAME/linear-import.md"
    record "projects/$PNAME/linear-import.md" "$PRDDIR/linear-import.md" "Linear import"
  fi

  # open-decisions register, where one exists
  #
  # A project's live open decisions belong beside its PRDs, not inside a dated handoff run.
  # Copied explicitly rather than falling out of the PRD sweep below, so it is recorded as its
  # own artifact type and never counted as a PRD.
  if [ -f "$REPO_ROOT/$PRDDIR/$P-open-decisions.md" ]; then
    cp "$REPO_ROOT/$PRDDIR/$P-open-decisions.md" "$PKG/projects/$PNAME/$P-open-decisions.md"
    record "projects/$PNAME/$P-open-decisions.md" "$PRDDIR/$P-open-decisions.md" "Open decisions"
  fi

  # mockups, where they exist
  #
  # Design artifacts, copied whole. A reader of a UI-bearing project could otherwise not tell
  # that mockups exist at all; the manifest records the directory rather than every asset.
  if [ -d "$REPO_ROOT/$PDIR/5_mockups" ]; then
    mkdir -p "$PKG/projects/$PNAME/mockups"
    cp -R "$REPO_ROOT/$PDIR/5_mockups/." "$PKG/projects/$PNAME/mockups/"
    record "projects/$PNAME/mockups/" "$PDIR/5_mockups" "Mockups"
  fi

  # PRDs — select by exclusion: PROJ-1 does not use the PROJ-<N>-PRD-<n>- convention
  N_PRD=0; N_US=0
  ( cd "$REPO_ROOT" && find "$PRDDIR" -maxdepth 1 -name '*.md' | sort ) | while IFS= read -r F; do
    B="$(basename "$F")"
    case "$B" in
      *manifest*|*review*|*changelog*|linear-import*|README*|*analysis*|*agenda*|*summary*|*open-decisions*) continue ;;
    esac
    cp "$REPO_ROOT/$F" "$PKG/projects/$PNAME/PRDs/$B"
    record "projects/$PNAME/PRDs/$B" "$F" "PRD"
    U="$(grep -cE '^### UC-[a-z0-9-]+-[0-9]{2} — As an? |^#{2,4} .*US-?[0-9]+' "$REPO_ROOT/$F" || true)"
    printf '%s\t%s\n' "1" "${U:-0}" >> "$TMP/counts"
  done

  printf '%s\n' "$P" >> "$TMP/projs"
done

if [ -f "$TMP/counts" ]; then
  PRD_TOTAL="$(awk -F'\t' '{s+=$1} END{print s+0}' "$TMP/counts")"
  US_TOTAL="$(awk -F'\t' '{s+=$2} END{print s+0}' "$TMP/counts")"
fi

# ---------------------------------------------------------------- link rewriting

# Every markdown link inside the package must resolve inside the package. Rewrite the
# forms that actually occur; selfcontain-check.sh (B7) is the backstop that proves the
# result rather than trusting this list.
echo "Rewriting links to package-relative form…"

# 1 · release working docs -> their frozen package names
while IFS='|' read -r FROM TO; do
  [ -z "$FROM" ] && continue
  find "$PKG" -name '*.md' -exec sed -i '' "s|(\./$FROM)|($TO)|g; s|($FROM)|($TO)|g; s|(\.\./$FROM)|($TO)|g" {} +
done < "$TMP/renames"

# 2 · source PRD paths -> packaged PRD paths, for every in-slice project
for P in $IN_SLICE; do
  PDIR="$( cd "$REPO_ROOT" && find specs -maxdepth 1 -type d -name "$P-*" | head -1 )"
  [ -z "$PDIR" ] && continue
  PNAME="$(basename "$PDIR")"
  find "$PKG" -name '*.md' -exec sed -i '' \
    -e "s|(\.\./$PNAME/2_PRDs/|(../../$PNAME/PRDs/|g" \
    -e "s|(\.\./$PNAME/3_PRDs/|(../../$PNAME/PRDs/|g" \
    -e "s|(specs/$PNAME/2_PRDs/|(projects/$PNAME/PRDs/|g" \
    -e "s|(specs/$PNAME/3_PRDs/|(projects/$PNAME/PRDs/|g" \
    -e "s|(\.\./$PNAME/1_brainstorm/$P-concept\.md)|(../../$PNAME/$P-concept.md)|g" {} +
done

# 3 · links that leave the package entirely -> demote to plain text, preserving the
#     wording. A reader is told the target lives in the source repo; nothing pretends
#     to resolve. Covers ../, specs/, and the ./reference/ sub-trees that concepts use
#     for their superseded material (deliberately not packaged — audit trail).
find "$PKG" -name '*.md' -exec sed -i '' -E \
  -e 's|\[([^]]+)\]\(\.\./[^)]*\)|\1 (source repo)|g' \
  -e 's|\[([^]]+)\]\((specs/[^)]*)\)|\1 (source repo: `\2`)|g' \
  -e 's|\[([^]]+)\]\(\./reference/[^)]*\)|\1 (source repo: concept reference/)|g' \
  -e 's|\[([^]]+)\]\(reference/[^)]*\)|\1 (source repo: concept reference/)|g' {} +

# ---------------------------------------------------------------- generated files

IN_SLICE_STR="$(printf '%s, ' $IN_SLICE | sed 's/, $//')"
OUT_SLICE_STR="$(printf '%s, ' $OUT_OF_SLICE | sed 's/, $//')"
[ -z "$OUT_SLICE_STR" ] && OUT_SLICE_STR="none"

PREV="$( find "$OUT_DIR" -maxdepth 1 -type d -name "$RELEASE-v*" 2>/dev/null \
         | grep -v "/$PKG_NAME\$" | sort -V | tail -1 || true )"
if [ -n "$PREV" ]; then PREV_STR="\`$(basename "$PREV")\`"; else PREV_STR="none — first package"; fi

RELEASE_TITLE="$(head -1 "$SCOPE_FILE" | sed -E 's/^# //; s/ · Release Scope Index$//')"

ART_ROWS="$(awk -F'\t' '{printf "| `%s` | `%s` | %s |\n",$1,$2,$3}' "$TMP/artifacts")"
SNAP_ROWS="$(sort -u "$TMP/snapshot" | awk -F'\t' '{printf "| `%s` | `%s` |\n",$1,$2}')"

render() { # <template> <target> — substitutes @@NAME@@ from every T_NAME in the environment
  python3 - "$1" "$2" <<'PY'
import sys, os
tmpl, target = sys.argv[1], sys.argv[2]
s = open(tmpl).read()
for k, v in os.environ.items():
    if k.startswith("T_"):
        s = s.replace("@@%s@@" % k[2:], v)
open(target, "w").write(s)
PY
}

export T_RELEASE="$RELEASE" T_RELEASE_TITLE="$RELEASE_TITLE" T_VERSION="$VERSION"
export T_BUILD_DATE="$BUILD_DATE" T_REPO_HEAD="$REPO_HEAD" T_BRANCH="$BRANCH"
export T_PACKAGE_DIR="$PKG_NAME" T_SCOPE_FILE="$(rel "$SCOPE_FILE")" T_PREVIOUS="$PREV_STR"
export T_IN_SLICE="$IN_SLICE_STR" T_OUT_OF_SLICE="$OUT_SLICE_STR"
export T_PROJ_COUNT="$PROJ_TOTAL" T_PRD_COUNT="$PRD_TOTAL" T_US_COUNT="$US_TOTAL"
export T_ARTIFACT_ROWS="$ART_ROWS" T_SNAPSHOT_ROWS="$SNAP_ROWS"

render "$SKILL_DIR/templates/README.md.tmpl"           "$PKG/README.md"
render "$SKILL_DIR/templates/release-manifest.md.tmpl" "$PKG/release-manifest.md"

# 00-what-changed.md — a stub the skill fills in; recorded here so the reading order
# in README.md always resolves.
if [ -n "$PREV" ]; then
  cat > "$PKG/00-what-changed.md" <<EOF
# What Changed Since \`$(basename "$PREV")\`

**Pending.** Written by \`2e-release-package\` after the verification step, from the
manifest diff against the previous package.
EOF
else
  cat > "$PKG/00-what-changed.md" <<EOF
# What Changed — Initial Package

This is the first specs release package for **$RELEASE**. There is no previous run to
compare against.

Built $BUILD_DATE from \`$REPO_HEAD\` on \`$BRANCH\`, covering $PROJ_TOTAL projects,
$PRD_TOTAL PRDs and $US_TOTAL user stories. Read \`02-scope.md\` for what is in the
release and \`KNOWN-GAPS.md\` for what is not yet resolved.
EOF
fi

echo
echo "Wrote $PKG"
echo "  projects: $PROJ_TOTAL   PRDs: $PRD_TOTAL   user stories: $US_TOTAL"
echo "  files:    $(find "$PKG" -type f | wc -l | tr -d ' ')"
echo
echo "Next: verification (chain-check.sh + selfcontain-check.sh) writes VERIFICATION.md"
echo "      and KNOWN-GAPS.md into the package."

[ "$WARN" -eq 0 ] && exit 0
exit 2
