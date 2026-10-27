# .claude/

Claude Code's setup for this repo: `hooks/session-start.sh` installs the pinned Godot in cloud sessions and imports the project, and `skills/run-status/` is the run-status mod (the `/runs` command, a status line, and notices for the long tools' progress files that `tools/progress.gd` writes; `hooks/register.tsx` has its rules, `types/index.d.ts` the files' shape). `settings.json` holds the repo's Claude Code settings.

## Folders

| Folder | What it holds |
| --- | --- |
| `hooks/` | session-start.sh: installs the pinned Godot as `godot` in cloud sessions, then imports the project. |
| `skills/` | run-status/: the run-status mod for the long tools' progress. |

## Files

| File | What it is |
| --- | --- |
| `settings.json` | The repo's Claude Code settings (hooks and permissions). |
