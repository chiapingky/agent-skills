# AGENTS.md — checkpoint router

Drop this file into a workspace root, or append it to your harness's global instructions file. It is the portable entry point: it tells any agent *when* to use the checkpoint skills. The procedure lives in `skills/*/SKILL.md`, which the agent reads on demand.

Requires `CHECKPOINT_VAULT_PATH` to point at a git-versioned vault directory. See `INSTALL.md`.

## Triggers

Match these literally. Do not infer intent from a passing mention — if the user says "I should checkpoint later", that is not a trigger. If they say "checkpoint kafka-learning", it is.

| User says | Do this | Read |
|---|---|---|
| `start project <name>` / `new project <name>` | Scaffold `Projects/<name>/` from the templates, commit | `skills/checkpoint/SKILL.md` § Creating a New Project |
| `checkpoint` / `checkpoint <name>` / `save progress` | Update the resume capsule, sync knowledge, commit | `skills/checkpoint/SKILL.md` § Checkpoint Flow |
| `resume <name>` / `pick up <name>` / `continue <name>` | Load `checkpoint.md` + `dashboard.md`, continue | `skills/resume-checkpoint/SKILL.md` |
| `resume` / `list checkpoints` / `what projects do I have` | List projects with status and one-line position | `skills/resume-checkpoint/SKILL.md` § No Name Provided |
| `add task <text>` / `mark <task> done` / `what's left` | Edit `## Tasks`, commit | `skills/checkpoint/SKILL.md` § Workflows |
| `log this` / `log finding` / `note this down` | Append to `research-log.md`, commit | `skills/checkpoint/SKILL.md` § Research Log |
| `add to knowledge` / `record decision` | Add a bullet under a `### <Category>` heading, commit | `skills/checkpoint/SKILL.md` § Workflows |
| `what did we do on <date>` / `show me the log` | Read `research-log.md` — this is the only case where it is loaded | `skills/checkpoint/SKILL.md` § Research Log |

## Hard rules

1. **Resolve the vault first.** `CHECKPOINT_VAULT_PATH` → `OBSIDIAN_VAULT_PATH` → `./vault` → ask the user once. Resolve to an absolute path; never pass the variable name into a shell command.
2. **Commit after every write.** Stage only the files you changed. Commit message: `checkpoint(<project>): <summary>` or `checkpoint: <topic> — <summary>`. Verify with `git log --oneline -1`. If the commit cannot be made, say so explicitly — a checkpoint without a commit is a failed checkpoint, not a silent success.
3. **Never load `research-log.md` proactively.** It is append-only history, read only on explicit request. The whole point of this system is spending less context, not more.
4. **Never duplicate dashboard content into `checkpoint.md`.** The capsule is Current Position, Ruled Out, Context Window. It points at the dashboard for tasks and knowledge.
5. **`Ruled Out` accumulates.** Never delete an eliminated option. If one is re-opened, annotate it with the date and the reason.
6. **No absolute home paths inside checkpoint files.** Store project-relative or vault-relative paths so the vault survives a machine move.

## On resume

Operate as if the previous session was not interrupted:

- Loaded facts are ground truth until the user corrects them.
- Do not re-litigate ruled-out options unless the user re-opens them explicitly.
- If the user's new instruction contradicts a recorded decision, flag the conflict before acting.
- If two loaded checkpoints conflict, surface it and ask which wins.
- State the loaded position in one line, then the open tasks, then ask whether to proceed or redirect.

## Portability

- No tool names, no harness APIs. Read, write, run shell.
- If the harness has no skill loader, read `SKILL.md` as a plain file. That is sufficient.
- If the harness has no model selection, ignore `model:` markers on steps and proceed.
- If there is no git, write the files and report the missing commit — do not abandon the write.
