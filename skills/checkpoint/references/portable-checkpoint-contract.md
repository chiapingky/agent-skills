# Portable Checkpoint Contract

Use this contract to implement checkpoint behavior in other agentic tools.

## Goal

Persist enough structured session state that another agent can resume without full conversation history.

## Inputs

```json
{
  "conversation_summary": "<full or summarized session context>",
  "vault_root": "<absolute path to the vault, resolved from CHECKPOINT_VAULT_PATH>",
  "name": "<optional explicit project or topic name>",
  "today": "<YYYY-MM-DD>",
  "model": "<model that produced this session — recorded in Context Window>",
  "harness": "<agent harness name — recorded in Context Window>",
  "skills_loaded": ["<skills relevant to the project>"]
}
```

## Outputs

Two modes. Implement project mode first — it is what the skills do.

### Project mode (three files)

```text
<vault>/Projects/<project-name>/
├── dashboard.md       # Tasks + Knowledge. Rewritten in place.
├── research-log.md    # Append-only. Never rewritten.
└── checkpoint.md      # Resume capsule. Field-level updates only.
```

Load policy: a resume reads `checkpoint.md` + `dashboard.md`. `research-log.md` is read only on explicit request about past events.

### Legacy mode (single file)

For one-off topics that are not projects:

```text
<vault>/Checkpoints/<topic>.md
```


## Topic Detection

When no explicit name is provided:

1. Segment the conversation into independently resumable topics.
2. Propose topic names and destination files to the user.
3. Allow rename, merge, or drop.
4. Write only confirmed topics.

Skip confirmation only when there is clearly one topic.

## Frontmatter Schema

```yaml
topic: <topic name>
type: <design | learning | consulting | decision | process | other>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
status: <in-progress | concluded | blocked>
```

## Body Sections

Recommended order:

1. Context
2. Established Facts
3. Key Decisions
4. Constraints
5. Ruled Out
6. Current Position
7. Open Questions
8. Next Steps

Omit empty sections.

## Update Semantics

- Stable identity fields never change: `topic`, `type`, `created`.
- `updated` always changes.
- `Next Steps` is replaced.
- Facts, decisions, constraints, and ruled-out options accumulate.
- Corrections should be made in place with supersession notes when history matters.

## Commit Semantics

Writing a checkpoint is not complete until the change is committed.

1. `git -C <vault_root> rev-parse --is-inside-work-tree` — if this fails, `git init` the vault root.
2. Stage only the files written. Never `git add -A`.
3. `git commit -m "checkpoint(<project>): <summary>"` (or `checkpoint: <topic> — <summary>`).
4. `git -C <vault_root> log --oneline -1` — confirm the commit landed.

If git is unavailable or the commit fails, report the checkpoint as incomplete. Silent success is the one outcome that must never happen.

## Quality Gate

Before saving, ask:

- Could a fresh agent resume without asking for basic context?
- Are hard constraints explicit?
- Are closed decisions and ruled-out paths preserved?
- Are next steps concrete?

If not, revise before writing.
