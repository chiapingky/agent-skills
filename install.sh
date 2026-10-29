#!/usr/bin/env bash
# install.sh — install agent-skills into a harness skills directory.
# Bash 3.2 compatible (macOS default). No external dependencies beyond coreutils.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"

MODE="copy"
DEST=""
ONLY=""
FORCE=0

usage() {
  cat <<'EOF'
Usage: install.sh --dest <skills-dir> [options]

  --dest DIR     Target skills directory (required unless auto-detected).
  --copy         Copy skill directories. Default. Re-run after each git pull.
  --link         Symlink skill directories. Live updates, but requires the
                 harness to follow symlinked directories.
  --skills a,b   Install only these skills. Default: all under skills/.
  --force        Overwrite an existing install (copy mode) or relink (link mode).
  -h, --help     This text.

Examples:
  ./install.sh --dest ~/.claude/skills
  ./install.sh --dest .claude/skills --link --force
  ./install.sh --dest "$LOCALAPPDATA/hermes/skills" --skills checkpoint
EOF
}

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dest)   [ $# -ge 2 ] || die "--dest needs a value"; DEST="$2"; shift 2 ;;
    --copy)   MODE="copy"; shift ;;
    --link)   MODE="link"; shift ;;
    --skills) [ $# -ge 2 ] || die "--skills needs a value"; ONLY="$2"; shift 2 ;;
    --force)  FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

[ -d "$SKILLS_SRC" ] || die "no skills/ directory at $SKILLS_SRC"

# --- auto-detect destination ------------------------------------------------
if [ -z "$DEST" ]; then
  if [ -d "$HOME/.claude/skills" ]; then
    DEST="$HOME/.claude/skills"
  elif [ -n "${LOCALAPPDATA:-}" ] && [ -d "$LOCALAPPDATA/hermes/skills" ]; then
    DEST="$LOCALAPPDATA/hermes/skills"
  elif [ -d "$HOME/.local/share/hermes/skills" ]; then
    DEST="$HOME/.local/share/hermes/skills"
  else
    die "could not detect a skills directory — pass --dest <dir>"
  fi
  printf 'auto-detected dest: %s\n' "$DEST"
fi

mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"

# --- pick skills -----------------------------------------------------------
names=""
if [ -n "$ONLY" ]; then
  names="$(printf '%s' "$ONLY" | tr ',' ' ')"
else
  for d in "$SKILLS_SRC"/*/; do
    [ -f "$d/SKILL.md" ] || continue
    names="$names $(basename "$d")"
  done
fi

[ -n "${names// /}" ] || die "no skills found under $SKILLS_SRC"

# --- install ---------------------------------------------------------------
for name in $names; do
  src="$SKILLS_SRC/$name"
  [ -f "$src/SKILL.md" ] || die "skill not found: $name"

  dst="$DEST/$name"

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ "$FORCE" -ne 1 ]; then
      printf 'skip  %-20s (exists — use --force to replace)\n' "$name"
      continue
    fi
    rm -rf "$dst"
  fi

  if [ "$MODE" = "link" ]; then
    ln -s "$src" "$dst"
    printf 'link  %-20s -> %s\n' "$name" "$src"
  else
    cp -R "$src" "$dst"
    printf 'copy  %-20s -> %s\n' "$name" "$dst"
  fi
done

printf '\ndone. dest: %s\n' "$DEST"
printf 'vault: %s\n' "${CHECKPOINT_VAULT_PATH:-${OBSIDIAN_VAULT_PATH:-<unset — see INSTALL.md>}}"
