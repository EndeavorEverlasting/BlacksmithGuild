# Live Runtime Proof Admission — Operator Report

**Repo:** `EndeavorEverlasting/BlacksmithGuild`  
**Lane:** harness infrastructure / runtime proof admission  
**Audience:** human operators and fresh agents

## What is working

The repository already has launcher/window identity, runtime observation, command ACK, behavior artifacts, event continuity, and E2E validation. This admission layer closes the remaining proof-classification gap: the harness now owns the decision about whether a run reached static, launcher, command ACK, behavior-observed, or live-runtime proof.

The focused validator is:

```powershell
pwsh -NoProfile -File .\scripts\tbg\Test-TbgLiveRuntimeProofAdmission.ps1
```

It runs only tracked fixtures by default and performs no game, launcher, save, command-inbox, process, or network mutation.

## What the harness rejects

A `live_fresh_launch` proof packet fails closed when any of these conditions apply:

- `skipLaunch=true`;
- launch was never requested or never attempted;
- the TaleWorlds launcher process was not observed;
- a launcher HWND was not bound;
- PLAY/CONTINUE actuation was not dispatched;
- the game process was not observed;
- campaign attach or readiness was not observed;
- a required command was not issued or ACKed;
- command ACK exists but the required behavior was not observed;
- the behavior artifact is missing or stale;
- run/correlation continuity is broken.

`not attempted` is never silently rewritten as `environment blocked`. **Agent prose cannot promote proof.** A model-supplied `claimedProofLevel` is not authoritative; the validator computes the proof level from the observed chain.

## Proof ladder enforced

```text
contract -> harness -> static test -> build -> launcher -> command ACK -> behavior observed -> live runtime
```

Only the complete fresh chain can return `PASS_LIVE_RUNTIME`.

## Modes

| Mode | Purpose | Maximum claim |
|---|---|---|
| `static_validation` | contracts, fixtures, validators | `static_test` |
| `live_fresh_launch` | owned fresh launcher-to-behavior run | `live_runtime` |
| `attach_existing` | explicitly authorized attachment to an existing owned runtime | `live_runtime` |

`attach_existing` fails closed without explicit attach authority.

## Artifacts

Registry: `.tbg/harness/live-runtime-proof-artifacts.registry.json`

Latest validator outputs:

- `artifacts/latest/live-runtime-proof-admission/live-runtime-proof-admission.result.json`
- `artifacts/latest/live-runtime-proof-admission/live-runtime-proof-admission.report.md`

Raw live evidence remains ignored/local under `.local/`; only sanitized fixtures or bounded evidence capsules belong in Git.

## Fresh-agent procedure

1. Read `AGENTS.md`, `CODEBASE_MAP.md`, and `.tbg/skills/runtime-evidence-certification/SKILL.md`.
2. Read `.tbg/workflows/live-runtime-proof-admission.contract.json`.
3. Run `Test-TbgLiveRuntimeProofAdmission.ps1` before attempting any live certification lane.
4. Use only the workflow-owned runtime launcher/certifier; do not add `-SkipLaunch` to a `live_fresh_launch` run.
5. Feed the workflow-owned proof packet to the validator with `-InputPath`.
6. Report the validator terminal state and computed proof level. Do not promote it in prose.
7. Preserve failure artifacts and hand off the exact failed stage.

## What remains outside this harness sprint

This layer does **not** rewrite launcher actuation, product behavior, or save handling. Coordinate/mouse/focus actuator replacement remains a separate launcher-surface implementation lane. A live cert runner must still produce the real evidence packet; this layer decides whether that packet is admissible.

## Handoff contract

A handoff must name:

- mode;
- run ID and correlation ID;
- terminal state;
- computed proof level;
- first failed or blocked stage;
- result/report paths;
- Git branch/commit/PR state;
- one exact next executable command.

If the terminal state is not `PASS_LIVE_RUNTIME`, the handoff must not call the run a live pass.
