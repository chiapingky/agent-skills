# Install

Three things must be true before the skills work anywhere:

1. The skill directories are somewhere your agent reads.
2. `CHECKPOINT_VAULT_PATH` resolves in the shell your agent runs in.
3. The vault is a git repository.

Nothing else. There is no daemon, no package manager, no API key.

---

## 1. Vault

The vault is just a directory of markdown in a git repo. Any location works.

### macOS with a `~/Git/`-only policy

```bash
mkdir -p ~/Git/vault
cd ~/Git/vault
git init -b main
mkdir -p Projects Checkpoints Knowledge
printf '# Vault\n\nCheckpoint state for all projects.\n' > README.md
git add README.md && git commit -m "vault: init"
```

Keep the vault inside `~/Git/` and nothing else is needed — the policy is satisfied because the skills only ever touch files under the vault path you give them.

If you already have a vault on another machine:

```bash
cd ~/Git
git clone <vault-remote> vault
```

### Environment variable

Add to `~/.zshrc` (macOS default shell) or `~/.bashrc`:

```bash
export CHECKPOINT_VAULT_PATH="$HOME/Git/vault"
```

`OBSIDIAN_VAULT_PATH` is also honoured — both skills try `CHECKPOINT_VAULT_PATH` first, then `OBSIDIAN_VAULT_PATH`, then `./vault`. Use whichever you prefer; the neutral name is recommended so nothing in the setup implies Obsidian.

Verify in a **new** shell:

```bash
echo "$CHECKPOINT_VAULT_PATH"
test -d "$CHECKPOINT_VAULT_PATH/.git" && echo "vault ok"
```

The agent inherits the environment of the process that launched it. If you export the variable in a terminal but launch the agent from the Dock, it will not see it. Restart the agent from a shell, or put the export in the file that the launcher actually sources.

### Optional git remote

```bash
cd ~/Git/vault
git remote add origin git@github.com:<you>/<vault-repo>.git
git push -u origin main
```

Use a **private** repository. The vault contains your notes, decisions, and project state.

---

## 2. Skills

### Claude Code

Personal (all projects):

```bash
./install.sh --dest ~/.claude/skills
```

Project-scoped (travels with the repo):

```bash
./install.sh --dest .claude/skills
```

Result: `~/.claude/skills/checkpoint/SKILL.md`, `~/.claude/skills/resume-checkpoint/SKILL.md`. Claude Code discovers skills by the `name` + `description` frontmatter, which both files already carry.

### Codex CLI

Codex has no skill loader. Use the router:

```bash
cp AGENTS.md ~/.codex/AGENTS.md          # global
cp AGENTS.md ./AGENTS.md                 # or per-repo
mkdir -p ~/.codex/skills && cp -r skills/* ~/.codex/skills/
```

Then reference the skill files from a prompt, or let the agent read them on trigger — `AGENTS.md` names the exact paths.

### Cursor, Windsurf, Aider, anything reading `AGENTS.md`

```bash
cp AGENTS.md ./AGENTS.md
cp -r skills ./skills
```

`AGENTS.md` routes triggers to `skills/*/SKILL.md`, which the agent reads like any other file.

### Hermes (optional)

```bash
./install.sh --dest "$LOCALAPPDATA/hermes/skills"     # Windows
./install.sh --dest ~/.local/share/hermes/skills       # Linux
```

Confirm with `hermes skills list`. On macOS the profile directory varies by install method — check what `hermes skills list` reports and match it.

### No harness at all

A human can run this entirely by hand. Copy `templates/*.md` into `<vault>/Projects/<name>/` and follow `skills/checkpoint/SKILL.md` as a checklist. `references/portable-checkpoint-contract.md` is a formal spec if you want to reimplement it in a different tool, including non-agentic ones.

---

## 3. Verify

One round trip is the whole test:

```
you:  start project demo
      → Projects/demo/{dashboard,research-log,checkpoint}.md created, committed

you:  add task write the migration
      → unchecked task in dashboard.md, committed

you:  checkpoint demo
      → checkpoint.md Current Position updated, committed

[ new session, possibly a different machine, possibly a different model ]

you:  resume demo
      → "Resumed: demo (in-progress) — <position>", open tasks listed
```

Check the commit happened:

```bash
git -C "$CHECKPOINT_VAULT_PATH" log --oneline -5
```

Expect `checkpoint(demo): ...` messages. If the files changed but there are no commits, the agent skipped the git step — re-ask explicitly and verify again.

---

## 4. install.sh

```
./install.sh --dest <skills-dir> [--copy | --link] [--skills a,b] [--force]
```

| Flag | Effect |
|---|---|
| `--dest DIR` | Target skills directory. Created if missing. |
| `--copy` | Copy directories (default). Deterministic; re-run after `git pull`. |
| `--link` | Symlink each skill. Live-updates on `git pull`, but depends on the harness following symlinked directories — unverified for most harnesses. On Git-Bash for Windows `ln -s` silently copies instead, so `--link` degrades to `--copy` there. |
| `--skills a,b` | Install a subset. Default: every directory under `skills/`. |
| `--force` | Overwrite an existing install. |

Copy is the default because symlink-following is not guaranteed. If a linked skill does not appear in the harness's list command, re-run with `--copy`.

Run it from the repo root, or anywhere — it resolves its own location.

---

## 5. Updating

```bash
cd ~/agent-skills && git pull
./install.sh --dest <skills-dir> --force
```

With `--link` installs, `git pull` alone is sufficient.

The vault is a separate repo and updates independently:

```bash
git -C "$CHECKPOINT_VAULT_PATH" pull
```

Always pull the vault **before** resuming on a second machine, or you will checkpoint against stale state and produce a divergent history.

---

## 6. Uninstall

```bash
rm -rf <skills-dir>/checkpoint <skills-dir>/resume-checkpoint
```

Delete the `AGENTS.md` copy if you installed one. The vault is untouched — it is your data, not part of the install.
