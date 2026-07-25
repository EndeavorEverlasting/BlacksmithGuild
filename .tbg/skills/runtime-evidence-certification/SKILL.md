---
name: runtime-evidence-certification
description: Classify freshness, exact-head identity, installed and loaded assemblies, command correlation, crash observability, behavior evidence, machine proof admission, proof levels, and retention before runtime claims.
---

# Skill: runtime-evidence-certification

## Use when

- A request uses words such as proved, passed, loaded, launched, attached, moved, arrived, traded, crashed, worked, live cert, or runtime proof.
- Inspecting runtime artifacts, exact-head identity, installed DLL hashes, loaded assembly identity, launcher/game attachment, command correlation, or process terminal evidence.
- Reconstructing a crash from pre-state, post-state or process-loss, expected signals, observed signals, valid negative evidence, and correlated spans.
- Consuming a completed runtime incident result to classify freshness and proof without promoting its classification.
- Deciding the highest proof level supported by fresh evidence.
- Archiving or retaining runtime evidence.

## Do not use when

- Writing product behavior as part of an evidence-only lane.
- Treating stale `Status.json`, parser success, command ACK, route assignment, a checkpoint, launcher invocation, the last log marker, or process non-observation as completion or root cause.
- Inferring movement, arrival, trade, negative evidence, game launch, campaign attachment, behavior, or native crash confirmation without fresh correlated supporting evidence.
- Deleting evidence before its owner, head, freshness, proof value, and replacement are recorded.
- Reclassifying a skipped or not-attempted launch as an environment blocker.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/live-runtime-proof-admission.contract.json` for live/runtime claims
4. `.tbg/harness/live-runtime-proof-artifacts.registry.json`
5. `.tbg/workflows/runtime-context-continuity.contract.json`
6. `.tbg/harness/schemas/runtime-context-capsule.schema.json`
7. `docs/operator/live-runtime-proof-admission.md`
8. `docs/handoff/runtime-state-routing.md`
9. `.tbg/harness/artifact-engines.registry.json`
10. `ForgeAgentStatus.cmd`
11. the fresh runtime and artifact-engine packets named by the active workflow
12. `artifacts/latest/window-lifecycle/window-lifecycle.result.json` when present
13. `artifacts/latest/artifact-engine/window-lifecycle-boundary.result.json` when present
14. `artifacts/latest/runtime-incident/runtime-incident-assembler.result.json` when present

## Proof ladder

```text
contract -> harness -> static test -> build -> launcher -> command ACK -> behavior observed -> live runtime
```

Every result must state freshness, branch or exact head when relevant, evidence paths, allowed claims, forbidden claims, and the proof ceiling actually reached. Raw logs, saves, crash dumps, secrets, and personal paths remain ignored; remote analysis uses a bounded sanitized `TbgRuntimeContextCapsule.v1` under `docs/evidence/runtime-context`. Window-lifecycle artifacts and the `window-lifecycle-boundary` packet are correlation inputs only; they never replace live runtime evidence or promote action dispatch into product proof.

Incident assembler results are correlation inputs only. `incident_ready` means a bounded report is available; it does not mean Bannerlord is live, certified, safe to restart, or safe to clean up.

## Machine live-proof admission

For any live/runtime proof request, the harness decides the terminal state. Agent prose does not.

Before a live run, execute:

```powershell
pwsh -NoProfile -File .\scripts\tbg\Test-TbgLiveRuntimeProofAdmission.ps1
```

A `live_fresh_launch` workflow must not use `-SkipLaunch` or an equivalent suppression. If launch was not requested, return `BLOCKED_LAUNCH_NOT_REQUESTED`; if launch was requested but not attempted, return `FAIL_LAUNCH_NOT_ATTEMPTED`. Do not rename either condition as `ENVIRONMENT BLOCKED`.

A live pass requires one fresh correlated chain containing launcher request/attempt, launcher process, launcher HWND, launch action, game process, campaign attach/readiness, command or trigger issue, ACK, observed behavior, and the workflow-owned runtime artifact. Command ACK without behavior is `FAIL_BEHAVIOR_NOT_OBSERVED`. Stale evidence or a correlation break fails closed. Ignore any model-supplied `claimedProofLevel`; use the validator-computed proof level.

For a workflow-owned proof packet:

```powershell
pwsh -NoProfile -File .\scripts\tbg\Test-TbgLiveRuntimeProofAdmission.ps1 -InputPath <proof-packet.json>
```

Report the resulting terminal state and proof level exactly. A nonzero exit code is a failed/blocked admission, not permission to substitute a lower proof claim.

## Crash observability

Before a crash-sensitive engine or API operation, preserve a correlated pre-state and declared expected signals. When control returns, preserve the matching post-state and observed signals. When the process disappears first, preserve the open span and process-loss boundary with a null post-state.

Negative evidence requires a declared signal, an identified active observer, a fresh source, a completed observation window, and an explicit absence. Silence from a stale log or missing observer is unknown, not negative evidence. The last marker is an execution boundary, not a cause.

Separate observation, inference, hypotheses, and proven cause. A `native_crash_confirmed` claim requires correlated external terminal evidence. After a crash, the observability gate passes only when a fresh agent who was not present can reconstruct the operation, state boundary, expected, observed, and absent signals, active span, terminal process evidence, exact head, causality status, and next decision from sanitized artifacts.

## Owned scope

- evidence classification and manifests
- exact-head and installed/loaded identity comparison
- freshness and command-correlation checks
- launcher/game/campaign proof-stage classification
- machine live-proof admission results and reports
- pre-state, post-state, expected-signal, observed-signal, and negative-evidence classification
- process terminal evidence and crash reconstruction reports
- proof-boundary reports
- evidence retention decisions
- runtime-evidence documentation and validators
- sanitized remote runtime-context capsules and their retention policy

## Forbidden scope

- unrequested gameplay changes
- launcher implementation changes
- save or command-inbox mutation
- claim promotion without evidence
- promoting launcher invocation, command ACK, a last marker, stale log silence, or process non-observation into behavior/live proof or root cause
- evidence deletion without archive or supersession proof
- committing raw logs, saves, crash dumps, credentials, tokens, private configuration, or absolute personal paths

## Validation

```powershell
pwsh -NoProfile -File scripts/tbg/Test-TbgLiveRuntimeProofAdmission.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgRuntimeContextContinuity.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
.\ForgeAgentStatus.cmd
.\ForgeArtifactEngine.cmd run -Mode observe
git diff --check
```

Run workflow-specific build, launcher, command, movement, arrival, trade, and live-crash validators only when the active contract grants that authority.

## Done gate

- The exact claim is mapped to a named proof level.
- Freshness and identity are explicit.
- Every evidence path exists or is reported missing.
- Live proof was admitted by `Test-TbgLiveRuntimeProofAdmission.ps1`; no skipped launch, stale evidence, ACK-only result, or correlation break was promoted.
- Crash-sensitive operations have a pre-state, post-state or process-loss boundary, declared expected signals, observed signals, valid negative evidence, and a correlated active span.
- Observation, inference, hypotheses, and proven cause are separated; confirmed native crashes have external terminal evidence.
- A fresh agent can reconstruct the failure from sanitized artifacts, or the observability gap is reported as the blocker.
- Allowed and forbidden claims are recorded.
- Retention or deletion disposition is recorded; failures needing remote review have a schema-valid sanitized capsule or an explicit reason none is required.
- No higher proof level is inferred from a lower one.
