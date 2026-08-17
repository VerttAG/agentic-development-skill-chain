#!/usr/bin/env bash
# Install the agentic development skill chain into any agent.
#
# One canonical copy lives in <root>/.agents/skills/ — the path Codex, Cursor,
# Gemini CLI, Copilot, Amp, OpenCode, Zed and others read natively. Hosts with
# their own directory (Claude Code) get a symlink per skill pointing at that
# canonical copy, so there is exactly one copy on disk to update.
#
# Usage:
#   ./install.sh                                  # all detected hosts, user scope, symlinked
#   ./install.sh --target claude                  # one host
#   ./install.sh --target codex --dest ./myrepo   # project scope
#   ./install.sh --copy                           # real directories instead of symlinks
#   ./install.sh --list                           # print what would be installed, write nothing
#   ./install.sh --uninstall                      # remove this chain from the selected targets
#
# Bash 3.2 compatible (stock macOS). No Node, no network, no registry.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/skills"

TARGET="all"
DEST=""
MODE="link"
ACTION="install"

# Skill directory names this chain has ever shipped. Used to remove orphans left
# by earlier versions (the pre-2.0 underscore names, and skills since dropped).
LEGACY_NAMES="0_chain-guide 0a_product-vision 0b_intake 0c_bootstrap 1_brainstorming
1b_visual-companion 1c_frontend-design 1c_design-intake 1d_ui-mockup 1e_concept-sync
2_requirements-engineer 2b_handoff-package 2c_review-reconcile 2d_release-scope
2e_release-package 3_architecture 3a_cross-review 4_writing-plans 4a_checkpoint
4b_setup 5_executing 6_qa 7_documentation 8_delivery autonomous-execution"

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --target)    TARGET="${2:?--target needs a value}"; shift 2 ;;
    --dest)      DEST="${2:?--dest needs a value}"; shift 2 ;;
    --global)    DEST=""; shift ;;
    --copy)      MODE="copy"; shift ;;
    --link)      MODE="link"; shift ;;
    --list)      ACTION="list"; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    -h|--help)   usage 0 ;;
    *) echo "install.sh: unknown option $1" >&2; usage 64 ;;
  esac
done

case "$TARGET" in
  all|claude|codex|agents|cursor) ;;
  *) echo "install.sh: --target must be one of: all claude codex agents cursor" >&2; exit 64 ;;
esac

[ -d "$SRC" ] || { echo "install.sh: $SRC not found" >&2; exit 1; }

# Canonical location: project scope when --dest is given, user scope otherwise.
if [ -n "$DEST" ]; then
  [ -d "$DEST" ] || { echo "install.sh: --dest '$DEST' is not a directory" >&2; exit 1; }
  DEST="$(cd "$DEST" && pwd)"
  CANON="$DEST/.agents/skills"
  SCOPE="project ($DEST)"
else
  CANON="$HOME/.agents/skills"
  SCOPE="user"
fi

# Hosts that need a symlink of their own. Codex, Cursor, Gemini CLI, Copilot,
# Amp, OpenCode and Zed all read the canonical .agents/skills path directly.
link_dir_for() {
  case "$1" in
    claude) if [ -n "$DEST" ]; then echo "$DEST/.claude/skills"; else echo "$HOME/.claude/skills"; fi ;;
    cursor) if [ -n "$DEST" ]; then echo ""; else echo "$HOME/.cursor/skills"; fi ;;
    *)      echo "" ;;
  esac
}

selected_link_hosts() {
  case "$TARGET" in
    all)    echo "claude cursor" ;;
    claude) echo "claude" ;;
    cursor) echo "cursor" ;;
    *)      echo "" ;;
  esac
}

# Directories where EARLIER versions of this chain installed but the current
# layout never writes. They are swept on every install and uninstall regardless
# of --target, otherwise a 1.x user keeps a full stale copy forever: 1.x put the
# chain in ~/.codex/skills, which Codex does not even read as a skills path.
legacy_dirs() {
  [ -n "$DEST" ] && return 0
  echo "$HOME/.codex/skills"
}

SKILLS=""
for d in "$SRC"/*/; do
  [ -f "$d/SKILL.md" ] || continue
  SKILLS="$SKILLS $(basename "$d")"
done
COUNT=$(echo $SKILLS | wc -w | tr -d ' ')

if [ "$ACTION" = "list" ]; then
  echo "scope:     $SCOPE"
  echo "canonical: $CANON"
  echo "mode:      $MODE"
  for h in $(selected_link_hosts); do echo "symlink:   $(link_dir_for "$h")"; done
  echo "skills:    $COUNT"
  for s in $SKILLS; do echo "  $s"; done
  exit 0
fi

# Remove every name this chain owns — current and legacy — from a directory.
purge_dir() {
  local dir="$1" n
  [ -d "$dir" ] || return 0
  for n in $SKILLS $LEGACY_NAMES; do
    if [ -e "$dir/$n" ] || [ -L "$dir/$n" ]; then
      rm -rf "$dir/$n"
      echo "  removed $dir/$n"
    fi
  done
}

if [ "$ACTION" = "uninstall" ]; then
  echo "Uninstalling the skill chain ($SCOPE)"
  purge_dir "$CANON"
  for h in $(selected_link_hosts); do
    d="$(link_dir_for "$h")"; [ -n "$d" ] && purge_dir "$d"
  done
  for d in $(legacy_dirs); do purge_dir "$d"; done
  echo "Done."
  exit 0
fi

echo "Installing $COUNT skills — scope: $SCOPE, mode: $MODE"
mkdir -p "$CANON"

# Stale copies from any earlier version go first, so renamed or dropped skills
# do not linger. The current set is then written fresh.
purge_dir "$CANON"
for h in $(selected_link_hosts); do
  d="$(link_dir_for "$h")"; [ -n "$d" ] && purge_dir "$d"
done
for d in $(legacy_dirs); do purge_dir "$d"; done

for s in $SKILLS; do
  # -R plus an explicit .DS_Store sweep: macOS regenerates them constantly and
  # they must never ship into someone else's skills directory.
  cp -R "$SRC/$s" "$CANON/$s"
  find "$CANON/$s" -name '.DS_Store' -delete 2>/dev/null || true
done
echo "  canonical copy -> $CANON"

for h in $(selected_link_hosts); do
  d="$(link_dir_for "$h")"
  [ -n "$d" ] || continue
  # Only adopt a host that is actually present, unless it was named explicitly.
  # Creating ~/.cursor for someone who does not use Cursor is noise, not help.
  if [ "$TARGET" = "all" ] && [ ! -d "$(dirname "$d")" ]; then
    echo "  $h not installed (no $(dirname "$d")) — skipped"
    continue
  fi
  mkdir -p "$d"
  for s in $SKILLS; do
    if [ "$MODE" = "link" ]; then
      ln -s "$CANON/$s" "$d/$s"
    else
      cp -R "$CANON/$s" "$d/$s"
    fi
  done
  echo "  $h -> $d ($MODE)"
done

echo
echo "Done. Codex, Cursor, Gemini CLI, Copilot, Amp, OpenCode and Zed read"
echo "$CANON directly; Claude Code reads its own directory."
echo "Framework runs additionally need the Ponytail plugin on both providers —"
echo "see docs/installation.md."
