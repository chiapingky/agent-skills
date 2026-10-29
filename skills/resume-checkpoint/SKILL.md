---
name: resume-checkpoint
description: "Restore session context from checkpoint files and continue."
version: 2.1.0
---

# Resume Checkpoint

Restore previous session context from checkpoint files and operate as if the conversation had not been interrupted.

## Triggers

This skill fires when the user says any of:
- "resume", "resume <project-name>", "continue <project-name>"
- "pick up <project-name>", "pick up where I left off"
- "list checkpoints", "show checkpoints", "what projects do I have"

## Storage Path

### Resolving the vault root

Use the first of these that is set and exists (identical chain to the `checkpoint` skill):

| Priority | Source | Notes |
|----------|--------|-------|
| 1 | `CHECKPOINT_VAULT_PATH` env var | Harness-neutral name — preferred |
| 2 | `OBSIDIAN_VAULT_PATH` env var | Legacy name, still honoured |
| 3 | `./vault` relative to CWD | Local fallback |

Resolve to a concrete absolute path before use. If none resolve, ask the user once for the vault root.

### Project sessions

1. `<vault>/Projects/<project-name>/checkpoint.md` (+ dashboard.md)
2. `./vault/Projects/<project-name>/checkpoint.md` (fallback)

### Non-project / legacy sessions

| Priority | Path | When |
|----------|------|------|
| 1 | `<vault>/Checkpoints/<topic>.md` | Vault path is set |
| 2 | `./checkpoints/<topic>.md` | No vault path |

## Project vs Legacy Sessions

### Project Session

A project session has this structure:
```
<vault>/Projects/<project-name>/
├── dashboard.md       # Tasks + Knowledge
├── research-log.md    # Timestamped audit trail
└── checkpoint.md      # Resume capsule
```

### Legacy Session

A legacy session is a single file:
```
./checkpoints/<topic>.md    # Full checkpoint with all sections
```

## No Name Provided

When no project/topic name is given:

1. List all project folders in `<vault>/Projects/` (if vault exists)
2. List all legacy files in `./checkpoints/`
3. Present combined list with type indicators:

   ```
   Projects:
   - kafka-learning (in-progress) — Midway through consumer group deep-dive

   Legacy:
   - harness-setup (in-progress) — Config and skills setup
   ```

4. Ask which to resume.

## One Project Name Provided

For "resume <project-name>":

1. Check `<vault>/Projects/<project-name>/checkpoint.md` first
2. If found: load both `checkpoint.md` AND `dashboard.md`
3. If not found: fall back to `./checkpoints/<project-name>.md` (legacy)
4. If neither exists: tell the user and list available options

### Loading a Project Session

Read both files:
- `checkpoint.md` → Current Position, Ruled Out, Context Window
- `dashboard.md` → Tasks, Knowledge

Do NOT load `research-log.md` unless the user asks about past events.

Acknowledge in one line:

```
Resumed: <project-name> (in-progress) — <Current Position in <=10 words>
```

State open tasks from the dashboard and ask whether to proceed or redirect.

### Loading a Legacy Session

Read the single checkpoint file. Acknowledge:

```
Resumed: <topic> (in-progress) — <Current Position in <=10 words>
```

## Multiple Names Provided

For "resume <a> <b>":

1. Load all specified projects/topics
2. Flag any that don't exist and continue loading the rest
3. Keep each topic's context distinct
4. Acknowledge:

   ```
   Resumed 2 projects: kafka-learning (in-progress), notification-design (blocked)
   ```

5. Ask which to start with unless the user has already directed it.

## Behavior After Loading

Operate as if the previous conversation was not interrupted:

- Respect all constraints from loaded checkpoints
- Treat established facts as ground truth unless the user corrects them
- Do not re-litigate ruled-out options unless the user explicitly re-opens them
- Continue from the current position
- Preserve each topic as a distinct context unit
- If the user's new message contradicts a key decision, flag the conflict before proceeding
- If loaded checkpoints conflict with each other, surface the conflict and ask to resolve

## Model-Escalation Markers

A checkpoint step may carry a model marker on its own line:

```
- [ ] Refactor the retry logic   model: deep
```

The marker is advisory state stored in the checkpoint — not a harness feature. Semantics:

1. Compare the marker to the tier you are actually running on.
2. Already at or above it → proceed normally.
3. Below it → do **not** silently continue on the weaker model. Either:
   - the user restarts the session on the marked model (give the exact command for *their* harness), or
   - your harness can spawn a subprocess on a different model → run that single bounded step there, integrate the result, update the checkpoint.
4. Step is bounded and self-contained → act. Step is exploratory → ask which route the user prefers.
5. When you deliberately defer a step to a stronger model, write the marker on that step's line so the next resume sees it.

Harness examples — illustrations, not requirements:

| Harness | Switch to a stronger model |
|---------|----------------------------|
| Hermes | `/model <name>` in-session, or `hermes -z "<step>" -m <model> --provider <provider>` for a one-shot |
| Claude Code | `/model <name>` in-session, or `claude -p "<step>" --model <name>` |
| Codex CLI | `codex -m <model> "<step>"` |
| Plain chat | new conversation with the stronger model selected, paste the checkpoint |

If the harness offers no model choice, ignore the marker and proceed — a checkpoint must never deadlock a session.

## Updating After Resume

When the session ends or the user runs a checkpoint, update the checkpoint files using the checkpoint skill's field-level update rules. Do not replace files wholesale.

After ANY update to checkpoint/dashboard/research-log files, run the **mandatory Git Versioning steps** from the checkpoint skill — the same non-negotiable rule applies here:

- Stage only the changed file(s) — never `git add -A`
- `git init` first if the repo root has no git repository
- Commit with a descriptive message (`checkpoint(<project>): <summary>` or `checkpoint: <topic> — <summary>`)
- Verify the commit landed with `git -C <repo-root> log --oneline -1`
- If the commit fails, report an incomplete checkpoint — do not silently proceed

An updated checkpoint without a verified commit is a failed checkpoint.
