#!/usr/bin/env bash
# verify.sh — self-check for this repo. Portable: Linux, macOS, MSYS/Git-Bash.
# Run before committing skill changes.  Usage: ./verify.sh
set -uo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
# git rejects MSYS-style /c/... paths; hand it the drive-letter form when possible.
if command -v cygpath >/dev/null 2>&1; then GREPO="$(cygpath -m "$REPO")"; else GREPO="$REPO"; fi
TMP="$(mktemp -d "${TMPDIR:-/tmp}/agent-skills-verify.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

PASS=0 FAIL=0
ok()  { PASS=$((PASS+1)); printf 'ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$1"; }
chk() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
cr()  { git -C "$GREPO" show "$1" | tr -cd '\r' | wc -c | tr -d ' '; }
CRLF="$(printf '\r')"

echo "== structure =="
chk "SKILL.md present for every skill"   "[ -z \"\$(for d in '$REPO'/skills/*/; do [ -f \"\$d/SKILL.md\" ] || echo \"\$d\"; done)\" ]"
chk "install.sh executable"              "[ -x '$REPO/install.sh' ]"
chk "AGENTS.md router present"           "[ -f '$REPO/AGENTS.md' ]"

echo
echo "== frontmatter =="
for d in "$REPO"/skills/*/; do
  s="$(basename "$d")"; f="$d/SKILL.md"
  chk "$s: opens with ---"      "[ \"\$(head -1 '$f')\" = '---' ]"
  chk "$s: name == directory"   "grep -qx \"name: $s\" '$f'"
  chk "$s: has description"     "grep -q '^description: ' '$f'"
  chk "$s: has version"         "grep -q '^version: ' '$f'"
done

echo
echo "== portability invariants =="
chk "no shell-expanded vault var in skills"  "[ -z \"\$(grep -rn '\\\$OBSIDIAN_VAULT_PATH' '$REPO/skills')\" ]"
chk "resolution chain documented"            "grep -rq CHECKPOINT_VAULT_PATH '$REPO/skills'"
chk "no Obsidian wording in templates"       "[ -z \"\$(grep -rin obsidian '$REPO'/skills/*/templates 2>/dev/null)\" ]"
chk "no hardcoded home paths in skills"      "[ -z \"\$(grep -rnE '/(Users|home)/[A-Za-z]' '$REPO/skills' --include='*.md' | grep -v '<vault>')\" ]"

echo
echo "== git hygiene =="
chk "git reaches the repo"        "git -C '$GREPO' rev-parse --is-inside-work-tree"
EOL="$(git -C "$GREPO" ls-files --eol 2>/dev/null)"
chk "eol data non-empty"          "[ -n \"\$EOL\" ]"
chk "index holds no CRLF"         "[ -z \"\$(printf '%s' \"\$EOL\" | grep i/crlf)\" ]"
chk "install.sh blob is LF-only"  "[ $(cr HEAD:install.sh) -eq 0 ]"
chk "install.sh mode is 100755"   "git -C '$GREPO' ls-files -s install.sh | grep -q '^100755'"

echo
echo "== install.sh behaviour =="
DEST="$TMP/skills"
chk "--help exits 0"                  "bash '$REPO/install.sh' --help"
chk "full install succeeds"           "bash '$REPO/install.sh' --dest '$DEST'"
chk "both skills installed"           "[ -f '$DEST/checkpoint/SKILL.md' ] && [ -f '$DEST/resume-checkpoint/SKILL.md' ]"
chk "references/ copied"              "[ -f '$DEST/checkpoint/references/portable-checkpoint-contract.md' ]"
chk "all 3 templates copied"          "[ \$(ls '$DEST/checkpoint/templates' | wc -l) -eq 3 ]"

# capture output rather than piping into grep -q: pipefail + SIGPIPE would fail the test
r2="$(bash "$REPO/install.sh" --dest "$DEST" 2>&1)"
chk "re-run skips without --force"    "case \"\$r2\" in *skip*) true;; *) false;; esac"

r3="$(bash "$REPO/install.sh" --dest "$DEST" --skills checkpoint --force 2>&1)"
chk "--force reinstalls"              "case \"\$r3\" in *'copy  checkpoint'*) true;; *) false;; esac"

chk "unknown skill rejected"          "! bash '$REPO/install.sh' --dest '$TMP/x' --skills nope"
chk "unknown flag rejected"           "! bash '$REPO/install.sh' --bogus"
chk "installed tree has no CRLF"      "[ -z \"\$(grep -rl \"\$CRLF\" '$DEST' 2>/dev/null)\" ]"

# MSYS/Git-Bash: ln -s copies directories instead of linking, so -L cannot hold there.
if [ -n "${MSYSTEM:-}" ]; then
  printf 'skip  --link symlink test (MSYS ln -s copies; unverified on this host)\n'
else
  chk "--link creates a real symlink" "bash '$REPO/install.sh' --dest '$TMP/l' --link && [ -L '$TMP/l/checkpoint' ]"
fi

echo
printf 'pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
