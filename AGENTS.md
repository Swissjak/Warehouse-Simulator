# Warehouse Simulator — Codex Project Instructions

## Project
Warehouse Simulator is a Roblox warehouse-worker simulator written in Luau.

## Source of truth
Before changing gameplay code:
1. Read `docs/GDD.md`.
2. Read `docs/DEV_STATUS.md`.
3. Read the specification for the current milestone in `docs/stages/`.
4. Inspect the existing repository before proposing changes.

Do not invent gameplay rules that are already defined.
If important behavior for the current milestone is ambiguous, ask before implementing it.

## Scope discipline
Implement only the requested milestone.
Do not proactively build future systems.

## Architecture
Gameplay must be server-authoritative.

Never trust the client for:
- inventory state;
- storage state;
- ownership/locks;
- money or XP;
- task completion;
- rewards;
- quantities.

Project layout:
- `src/server` — server gameplay systems/services.
- `src/client` — client input, presentation, UI, local effects.
- `src/shared` — shared config, constants, types, pure utilities.

Prefer small focused modules, explicit config, typed Luau where practical, and server validation.
Avoid giant scripts, duplicated constants, hidden dependencies, unnecessary remotes, and magic numbers.

## Roblox Studio and Rojo
Rojo is intentionally partial.
Rojo owns the code mapped from `src/`.
Rojo does NOT own the warehouse world in `Workspace`.

Studio-authored content includes:
- warehouse geometry;
- `Workspace.Warehouse.RackZones`;
- rack templates `RackV1` and `RackV2`;
- visual rack design;
- slot/sticker reference parts.

Do not delete or recreate Studio-authored environment content unless explicitly requested.

## Development workflow
For a non-trivial milestone:
1. Read relevant docs.
2. Inspect existing code.
3. Give a concise implementation plan before coding.
4. Call out assumptions affecting Studio-authored objects.
5. Implement only the approved milestone.
6. Keep it testable in Studio.
7. Provide a manual Studio test checklist.
8. Update `docs/DEV_STATUS.md` only after the milestone is actually working.

## Current platform
MVP is PC-first. Do not implement mobile controls unless explicitly requested.

## Current milestone
`docs/stages/01-rack-generator.md`

## Communication language
Respond to the user in Russian.
Keep code, file names, class names, and identifiers in English.

## Git / GitHub workflow

GitHub is connected to this project.

Codex should manage Git commits when appropriate.

Rules:
- Do not commit every tiny edit.
- Keep one logical milestone/fix per commit.
- Before starting substantial work, inspect the current git status.
- After implementing a milestone, do not mark it stable until the user has tested it in Roblox Studio.
- After the user confirms the milestone works, create a clean commit for that milestone.
- Use concise descriptive commit messages.
- Do not rewrite history.
- Do not force-push.
- Do not rebase or reset existing user work unless explicitly requested.
- Never discard unrelated user changes.
- Push to GitHub after a stable milestone commit when repository permissions allow it.
