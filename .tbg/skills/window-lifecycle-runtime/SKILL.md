---
name: window-lifecycle-runtime
description: Inspect and interpret P19 window-lifecycle run context, events, state, result, report, and handoff artifacts. Guide reduce/replay/status and quarantine decisions without clicking or claiming live proof.
---

# Skill: window-lifecycle-runtime

## Use when

- Inspecting `artifacts/latest/window-lifecycle/*` or `.local/tbg-window-lifecycle/**`.
- Running `ForgeWindowLifecycle.cmd` validate, replay, or status.
- Interpreting lifecycle phases, transitions, unknown quarantine, or action-dispatch proof boundaries.
- Selecting bounded next actions from lifecycle state without launching or clicking.

## Do not use when

- Clicking, focusing, launching, sleeping, OCRing, or sending keys.
- Claiming modal acceptance, campaign readiness, command ACK, movement, arrival, buy, sell, or live gameplay.
- Editing lifecycle schemas, the pure reducer, or the P19 runtime adapter.
- Routing movement or trade work merely because lifecycle artifacts exist.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `docs/architecture/window-lifecycle-runtime-wiring.md`
4. `docs/architecture/window-lifecycle-agent-routing.md`
5. `.tbg/harness/schemas/window-lifecycle-run-context.schema.json`
6. `.tbg/harness/schemas/window-lifecycle-runtime-event.schema.json`
7. `ForgeWindowLifecycle.cmd`
8. `scripts/tbg/Invoke-TbgWindowLifecycleRuntime.ps1` (consume only)
9. `artifacts/latest/window-lifecycle/window-lifecycle.handoff.md` when present

## Proof boundary

```text
contract -> harness -> static fixture replay -> runtime-adapter execution -> launcher_lifecycle_harness
```

Lifecycle dispatch and host-handoff observation remain below campaign readiness and live runtime. Parser success and artifact-trigger PASS are not launcher acceptance.

## Owned scope

- `.tbg/skills/window-lifecycle-runtime/**`
- skill/capability/operation/trigger routing for lifecycle inspection
- interpretation of registered P19 lifecycle artifacts
- quarantine and no-action guidance for unknown windows

## Forbidden scope

- lifecycle schema redesign
- `scripts/tbg/Resolve-TbgWindowLifecycle.ps1`
- `scripts/tbg/Invoke-TbgWindowLifecycleRuntime.ps1`
- `scripts/tbg/Invoke-TbgWindowIntelligence.ps1`
- `scripts/launcher-window-context.ps1`
- `.github/workflows/window-lifecycle-harness.yml`
- MapTrade, save, inbox, or gameplay mutation
- click or live runtime mutation

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgWindowLifecycle.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgWindowLifecycleRuntime.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgArtifactEngine.ps1
git diff --check
```

## Done gate

- One primary skill is selected for lifecycle inspection.
- Registered P19 artifact filenames and schemas are consumed without alternate shapes.
- Unknown or quarantined state yields diagnostic or waiting guidance, never a click.
- Proof ceiling stays at harness or launcher observation unless a higher workflow grants more.
- Route, ACK, and live-runtime claims remain with their owning skills.
