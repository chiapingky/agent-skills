# agent-skills

Portable skills for AI coding agents. Plain markdown, plain shell, plain git. No runtime, no vendor lock-in, no SDK.

Current collection:

| Skill | Purpose |
|-------|---------|
| `checkpoint` | Writes durable project state — tasks, knowledge, decisions, a resume capsule — into a git-versioned vault |
| `resume-checkpoint` | Reads that state back and continues as if the session never ended |

Together they let you close a session on one machine, on one model, in one harness, and pick it up on another — or weeks later on the same one — without replaying context.

---

## Why this exists

Long work dies with the context window. Chat history is not a storage format: it is unsearchable, unversioned, and gone when the session ends or the machine changes.

| Lose the session, keep… | Without this | With this |
|---|---|---|
| Current position | "where was I?" | one paragraph, exact |
| Decisions | re-debated | recorded with rationale |
| Ruled-out paths | re-tried | accumulating list |
| Task list | in your head | checkboxes in git |
| Audit trail | nothing | timestamped log |

Everything is files. Files are diffable, reviewable, portable, and survive every harness migration.

---

## Requirements

- `git`
- A directory to act as the **vault** (a git repo). A remote is optional but recommended.
- An agent that can read a file, write a file, and run a shell command. That is the entire interface.

No Obsidian needed. No Python, Node, or Go. If you want to *browse* the vault as linked notes, install Obsidian and open the vault directory — it is a pure viewer and never required.

---

## Quickstart

```bash
git clone <this-repo> ~/agent-skills
cd ~/agent-skills

# 1. Create or reuse a vault. Any git repo works.
mkdir -p ~/Git/vault && cd ~/Git/vault
git init
mkdir -p Projects Checkpoints Knowledge

# 2. Point the skills at it (add to your shell profile)
export CHECKPOINT_VAULT_PATH="$HOME/Git/vault"

# 3. Install the skills into your harness (see INSTALL.md for paths)
~/agent-skills/install.sh --dest <your-harness-skills-dir>

# 4. Round trip
#    tell the agent:  start project demo
#    tell the agent:  add task write the migration
#    tell the agent:  checkpoint demo
#    new session, tell the agent:  resume demo

# 5. Self-check
~/agent-skills/verify.sh
```

If step 4 works, the setup is correct. `verify.sh` checks the repo itself, not your install.

---

## Layout

```
agent-skills/
├── README.md            # you are here
├── AGENTS.md            # trigger router — drop into any workspace, works with zero skill system
├── INSTALL.md           # per-harness install paths and env var setup
├── install.sh           # copies or links skills into a harness skills directory
├── verify.sh            # self-check: structure, frontmatter, portability, git hygiene, installer
└── skills/
    ├── checkpoint/
    │   ├── SKILL.md                          # authoritative procedure
    │   ├── references/portable-checkpoint-contract.md   # implement it in any tool, incl. non-agentic
    │   └── templates/{dashboard,research-log,checkpoint}.md
    └── resume-checkpoint/
        └── SKILL.md
```

`SKILL.md` is authoritative for *procedure*. `AGENTS.md` is authoritative for *when to trigger*. They do not duplicate each other.

---

## What lives in the vault

```
<vault>/Projects/<project-name>/
├── dashboard.md       # Tasks (checkboxes) + Knowledge (facts, decisions)
├── research-log.md    # append-only timestamped audit trail
└── checkpoint.md      # resume capsule: Current Position / Ruled Out / Context Window
```

Optional, for one-off work that is not a project:

```
<vault>/Checkpoints/<topic>.md
```

**Load policy matters more than the format.** A resume reads `checkpoint.md` + `dashboard.md` only. `research-log.md` is never loaded proactively — it exists to answer "what did we do on Tuesday", and loading it on every resume wastes the context you are trying to save.

Every write is followed by a git commit to the vault. A checkpoint that is not committed is a failed checkpoint.

---

## Triggers

Say these to the agent. No slash commands, no configuration.

| Phrase | Effect |
|---|---|
| `start project <name>` | Creates the three files from templates, commits |
| `checkpoint` / `checkpoint <name>` | Updates the resume capsule, syncs knowledge, commits |
| `resume <name>` / `pick up <name>` | Loads checkpoint + dashboard, continues |
| `resume` / `list checkpoints` | Lists projects with status and last position |
| `add task <text>` | Appends an unchecked task, commits |
| `mark <task> done` | Checks it off, commits |
| `log this` / `log finding` | Appends a timestamped research-log entry, commits |
| `add to knowledge` / `record decision` | Adds a knowledge bullet, commits |
| `what's left` | Reads tasks from the dashboard |
| `what did we do on <date>` | Reads the research log — the only time it is loaded |

---

## Harness and model agnosticism

The skills are written to four rules:

1. **No tool names.** Only "read a file", "write a file", "run a shell command".
2. **No hardcoded paths.** The vault comes from `CHECKPOINT_VAULT_PATH`, then `OBSIDIAN_VAULT_PATH`, then `./vault`, then an explicit question to the user.
3. **Graceful degradation.** If the harness has no model selection, escalation markers are ignored rather than deadlocking. If it has no skill system, `AGENTS.md` carries the triggers. If it has no git, the procedure still writes files and reports the missing commit.
4. **git is the only integration point.** Not an API, not a database, not a plugin hook.

That is why this works in Hermes, Claude Code, Codex, Cursor, a bare `python` REPL, or a human following the contract with a text editor.

If your harness has no skill system at all, use the `AGENTS.md` route — see below.

---

## Using it with no skill system

Copy `AGENTS.md` into the root of the workspace you want checkpointed, or into the harness's global instructions file. It routes triggers to `skills/checkpoint/SKILL.md` and `skills/resume-checkpoint/SKILL.md`, which the agent reads on demand like any other file.

This is the lowest common denominator and it is fully functional — skill-loading machinery is a convenience, not a requirement.

---

## Adding a new skill

```
skills/<skill-name>/
├── SKILL.md      # required: YAML frontmatter (name, description, version) + procedure
├── references/   # optional: long-form material loaded only when needed
├── templates/    # optional: files copied verbatim into the workspace
└── scripts/      # optional: executables the skill invokes
```

Rules:

- The `description` is the trigger. Keep the operative phrase in the first 57 characters — some harnesses truncate it in their skill index.
- Write the body as instructions to an agent, not documentation for a human.
- No tool names, no absolute paths, no vendor APIs.
- Test in a harness with no skill system first. If it works there, it works everywhere.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Agent says it cannot find the vault | Env var unset in the agent's shell, not yours | Export it in the profile the agent actually sources; or create `./vault` |
| Files written, no commit | Agent skipped the git step, or no repo | `git init` the vault; re-ask the agent to commit and verify with `git log --oneline -1` |
| Resume loads too much context | `research-log.md` was read | Restate the load policy: checkpoint + dashboard only |
| Two machines disagree | Both edited without pushing | Pull first, then resume; the vault is a normal git repo |
| Skill does not appear in the harness | Installed to the wrong skills directory, or the harness was not restarted | Confirm the path with the harness's own list command (see INSTALL.md) |
| Symlinked skill not detected | Harness does not follow symlinked directories | Re-run `install.sh --copy` |

---

## License

Private. Ask before redistributing.
