# Claude Adapter

Read `AGENTS.md` first. This file does not replace repository law.

Use progressive disclosure:

1. `AGENTS.md`
2. `CODEBASE_MAP.md`
3. `harness/api/agent-routing-manifest.json`
4. the selected `.claude/skills/*/SKILL.md`
5. only the capabilities declared by that skill
6. current code, workflow, and evidence paths required by the task

Do not preload every plan, historical handoff, evidence folder, or runtime log.

Claude-specific behavior:

- Prefer repo-owned scripts and manifests over ad hoc shell composition.
- Keep game, Windows, WSL, PowerShell, and terminal execution domains explicit.
- Do not infer live behavior from prose or a successful process exit.
- Do not issue game mutation commands without the selected runtime-proof workflow and its safety gate.
- Emit a schema-backed sprint capsule when handing work to another agent or repository.
