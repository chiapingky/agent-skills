---
name: checkpoint
description: "Project tracking: dashboard, research log, and session checkpoint."
version: 2.1.0
---

# Checkpoint

Unified project tracking skill. Covers three functions under one trigger set:

| Function | File | Purpose |
|----------|------|---------|
| **Dashboard** | `dashboard.md` | Tasks + Knowledge — the living project state |
| **Research Log** | `research-log.md` | Timestamped audit trail — what happened, when |
| **Checkpoint** | `checkpoint.md` | Resume capsule — Current Position, Ruled Out, Context |

All three live in the vault under `Projects/<project-name>/`. One skill, deterministic loading, no overlap.

## Triggers

**Session-level:**
- "checkpoint", "checkpoint <project>", "save progress"

**Live dashboard operations:**
- "add task <description>", "mark <task> done", "what's left to do"
- "log this", "log finding", "note this down"
- "add to knowledge", "record decision"
- "what did we do on <date>", "show me the log"

**Project lifecycle:**
- "start project <name>", "new project <name>"
- "resume <project>", "pick up <project>"

## Harness Neutrality

This skill must work in any agent harness (Hermes, Claude Code, Codex, a plain LLM chat with file access, a human following it by hand). Therefore:

- Refer only to generic capabilities: **read a file**, **write a file**, **run a shell command**. Never to a specific tool name.
- Never assume a skill-loading mechanism exists. If the agent can read `SKILL.md`, it has everything it needs.
- Harness-specific behaviour (model escalation, subagent spawning) goes in `resume-checkpoint`'s escalation section as an *example*, never as a hard rule.
- Paths come only from the resolution chain below — never from a hardcoded home directory.

## Storage Path

### Resolving the vault root

Use the first of these that is set and exists:

| Priority | Source | Notes |
|----------|--------|-------|
| 1 | `CHECKPOINT_VAULT_PATH` env var | Harness-neutral name — preferred |
| 2 | `OBSIDIAN_VAULT_PATH` env var | Legacy name, still honoured |
| 3 | `./vault` relative to CWD | Local fallback for throwaway workspaces |

Rules:

- Resolve to a **concrete absolute path** before using it. Never pass the variable name through to a shell command.
- If none resolve, do not guess — ask the user once for the vault root, then continue.
- The vault root should be a git repository. If it is not, `git init` it (see Git Versioning).

### Project sessions

```
<vault>/Projects/<project-name>/
├── dashboard.md
├── research-log.md
└── checkpoint.md
```

### Non-project / legacy sessions

| Priority | Path | When |
|----------|------|------|
| 1 | `<vault>/Checkpoints/<topic>.md` | A vault root resolved |
| 2 | `./checkpoints/<topic>.md` | No vault root |

Use the full checkpoint format (all sections) for non-project sessions.

## Dashboard (`dashboard.md`)

### Template

```markdown
---
project: <project-name>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

# <Project Title>

## Tasks

- [ ] <task description>
- [x] <completed task>

## Knowledge

### <Category>

- <established fact or finding>
- **Decision:** <decision and rationale>
```

### Rules

- Tasks use GitHub-style checkboxes (`- [ ]` / `- [x]`)
- Knowledge is organized by `### <Category>` headings (e.g., `### Architecture`, `### Decisions`, `### Findings`)
- Frontmatter `updated` changes whenever dashboard content changes
- Keep Knowledge entries declarative — one fact per bullet
- Don't delete completed tasks — they stay checked off as progress record
- When a Knowledge entry becomes obsolete, strike through (`~~text~~`) and add the new finding

### Workflows

**Adding a task:** Read dashboard → add `- [ ] <task>` under `## Tasks` → write back → git commit

**Marking done:** Read dashboard → change `- [ ] <task>` to `- [x] <task>` → write back → git commit

**Adding knowledge:** Read dashboard → add bullet under appropriate `### <Category>` (create if needed) → update `updated` → write back → git commit

**Resuming:** Read `dashboard.md` + `checkpoint.md` only. Do NOT load `research-log.md` unless asked.

## Research Log (`research-log.md`)

### Template

```markdown
# Research Log: <Project Title>

## <YYYY-MM-DD>

### <HH:MM> — <Entry Title>

<What was discovered, changed, or decided. Include rationale and context.>

---
```

### Rules

- Each day is an `## <YYYY-MM-DD>` heading
- Each entry is an `### <HH:MM> — <Title>` subheading
- Body is freeform — capture what changed, why, and implications
- Append-only — never rewrite history
- Only load when the user asks about past events (don't burn tokens proactively)

### Escalation Log Entries

For model-tier escalations (any harness that routes between a cheap and a deep model), use this one-line format as regular research-log entries:

```
- L2 spawn <timestamp>: trigger=<user|envelope|failure|contradiction>, task=<one-liner>, turns=<n>, result=<success|fail|runaway>, delta=<pro-improved|same|worse>, L3-needed=<yes|no>, why=<one-liner>
```

Append-only like any other entry. A calibration loop (human or agent) reviews ~10 of these and tightens the escalation triggers from the measured boundary.

### Workflow

**Logging:** Read research-log.md → check if today's heading exists → append new entry (create heading if needed) → write back → git commit

## Checkpoint (`checkpoint.md`)

The lean resume capsule. Does NOT duplicate dashboard content — references it.

### Template

```markdown
---
project: <project-name>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
status: <in-progress | concluded | blocked>
---

# Checkpoint: <Project Title>

## Current Position

<Exact state at checkpoint time. What you were doing, what you were about to do, leading hypothesis, confidence level, and what remains unclear. 2-4 sentences.>

## Ruled Out

- **<Option>:** <reason it was eliminated, with rationale>
- If a ruled-out option is re-opened, annotate with date and why.

## Context Window

- Model: <model used>
- Provider: <provider>
- Context cap: <context_length>
- Skills loaded: <list of relevant skills>

## Dashboard

See [dashboard.md](./dashboard.md) for tasks, knowledge, and decisions.
See [research-log.md](./research-log.md) for the chronological audit trail.
```

### Writing vs Updating

If no prior `checkpoint.md` exists, create it. If it exists, update field by field:

| Field | Rule |
|-------|------|
| `updated`, `status` | Replace |
| `Current Position` | Replace — always reflect now |
| `Ruled Out` | Accumulate — never remove. If re-opened, annotate. |
| `Context Window` | Replace with current state |
| `Dashboard` link | Always present — never changes |

## Git Versioning (Mandatory)

**Every content change to any checkpoint/tracking file MUST be committed to git immediately after the write. This is non-negotiable — a checkpoint write is NOT complete until its commit is verified.** Do not skip the commit even if the user only asked to write or update a file. Versioning is part of the write operation itself.

### Steps (in order, no exceptions)

1. **Resolve the repo root.** Tracking files live in either:
   - Project files: `<vault>/Projects/<project-name>/`
   - Legacy checkpoints: `./checkpoints/<topic>.md`

   If a vault root resolved, the vault directory is the intended repo root. For legacy `./checkpoints/`, use the file's own directory (or the nearest enclosing repo).

2. **Ensure a git repo exists.** Check first:
   ```bash
   git -C <repo-root> rev-parse --is-inside-work-tree
   ```
   If it fails (not a repo), run `git init` in the repo root BEFORE committing. Never skip versioning just because no repo exists — create one.

3. **Stage only the changed file(s).** Never `git add -A` blindly — stage the specific files written:
   ```bash
   git -C <repo-root> add Projects/<project-name>/dashboard.md
   ```

4. **Commit with a descriptive message:**
   ```bash
   git -C <repo-root> commit -m "checkpoint(<project>): <short summary of what changed>"
   ```

5. **Verify the commit landed.** Run `git -C <repo-root> log --oneline -1` and confirm the new commit is at the top. If the commit failed (nothing staged, pre-commit hook blocked it, etc.), resolve the cause and retry — do NOT report success without a verified commit.

### Commit Message Convention

- `checkpoint(<project>): <summary>` for project files
- `checkpoint: <topic> — <summary>` for legacy checkpoints
- Summary states the change: "add task X", "update Current Position", "log finding about Y"

### Failure Handling

If git is unavailable or the commit cannot be completed, report this explicitly to the user as an incomplete checkpoint — do not silently proceed. The user cares about version history; a checkpoint without a commit is a failed checkpoint.

## Creating a New Project

When the user says "start project <name>" or "new project <name>":

1. Create `Projects/<project-name>/` in the vault
2. Write `dashboard.md` from template
3. Write `research-log.md` from template
4. Write `checkpoint.md` from template
5. Run the mandatory Git Versioning steps (commit all three files) — do not skip
6. Confirm: "Project `<name>` ready at `Projects/<name>/`"

## Checkpoint Flow (End of Session)

When the user says "checkpoint" or "checkpoint <project>":

### With a named project

1. Read `dashboard.md` — sync any new knowledge/decisions from the session
2. Read `checkpoint.md` (if exists) — update per the field rules above
3. Write updated `checkpoint.md`
4. Run the mandatory Git Versioning steps — verify the commit landed
5. Confirm: "Checkpoint updated: `<project>` — `<current position in <=10 words>`"

### Without a name (auto-detect)

1. Scan the conversation for distinct topics
2. If all topics belong to one active project, checkpoint that project
3. If multiple projects or non-project topics detected, propose split:

   ```
   Found 2 topics:
   1. <project-a> → vault Projects/<project-a>/checkpoint.md
   2. <standalone-topic> → ./checkpoints/<topic>.md (legacy format)

   Confirm?
   ```

4. Wait for confirmation, then write each.

### Single topic detected

If the conversation is clearly one topic and that topic maps to an existing project, checkpoint it directly without asking.

## Pitfalls

- Never load `research-log.md` into context unless the user explicitly asks about past events
- Don't put detailed findings in tasks — tasks are pointers, knowledge captures details
- Don't duplicate dashboard content in checkpoint.md — checkpoint only has Current Position, Ruled Out, Context
- When the vault is at `./vault/`, resolve it relative to CWD, not the skill directory
- Legacy sessions (harness config, system setup) still use `./checkpoints/<topic>.md` with the full format
- Never hardcode a home directory in a checkpoint file — store project-relative or vault-relative paths so the vault stays portable across machines
