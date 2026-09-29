# Codex Setup Pack

Copy this pack into the root of your existing Rojo project.

Do not replace your existing `default.project.json`, `rokit.toml`, or `src/`.

Then commit:

```powershell
git add .
git commit -m "Add project instructions and Rack Generator specification"
```

Recommended first Codex prompt:

> Read AGENTS.md, docs/GDD.md, docs/DEV_STATUS.md, and docs/stages/01-rack-generator.md. Inspect the repository. Do not write code yet. First propose an implementation plan for Stage 01A only. Explicitly identify any assumptions about the RackV1/RackV2 model pivot or Studio hierarchy that must be confirmed before placement code is written.
