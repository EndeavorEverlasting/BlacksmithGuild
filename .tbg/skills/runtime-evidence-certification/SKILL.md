---
name: runtime-evidence-certification
description: Classify freshness, exact-head identity, installed and loaded assemblies, command correlation, crash observability, behavior evidence, proof levels, and retention before runtime claims.
---

# Skill: runtime-evidence-certification

## Use when

- A request uses words such as proved, passed, loaded, moved, arrived, traded, crashed, or worked.
- Inspecting runtime artifacts, exact-head identity, installed DLL hashes, loaded assembly identity, command correlation, or process terminal evidence.
- Reconstructing a crash from pre-state, post-state or process-loss, expected signals, observed signals, valid negative evidence, and correlated spans.
- Deciding the highest proof level supported by fresh evidence.
- Archiving or retaining runtime evidence.

## Do not use when

- Writing product behavior as part of an evidence-only lane.
- Treating stale `Status.json`, parser success, command ACK, route assignment, a checkpoint, the last log marker, or process non-observation as completion or root cause.
- Inferring movement, arrival, trade, negative evidence, or native crash confirmation without fresh correlated supporting evidence.
- Deleting evidence before its owner, head, freshness, proof value, and replacement are recorded.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/runtime-context-continuity.contract.json`
4. `.tbg/harness/schemas/runtime-context-capsule.schema.json`
5. `docs/handoff/runtime-state-routing.md`
6. `.tbg/harness/artifact-engines.registry.json`
7. `ForgeAgentStatus.cmd`
8. the fresh runtime and artifact-engine packets named by the active workflow
9. `artifacts/latest/window-lifecycle/window-lifecycle.result.json` when present
10. `artifacts/latest/artifact-engine/window-lifecycle-boundary.result.json` when present

## Proof ladder

```text
contract -> harness -> static test -> build -> launcher -> command ACK -> behavior observed -> live runtime
```

Every result must state freshness, branch or exact head when relevant, evidence paths, allowed claims, forbidden claims, and the proof ceiling actually reached. Raw logs, saves, crash dumps, secrets, and personal paths remain ignored; remote analysis uses a bounded sanitized `TbgRuntimeContextCapsule.v1` under `docs/evidence/runtime-context`. Window-lifecycle artifacts and the `window-lifecycle-boundary` packet are correlation inputs only; they never replace live runtime evidence or promote action dispatch into product proof.

## Crash observability

Before a crash-sensitive engine or API operation, preserve a correlated pre-state and declared expected signals. When control returns, preserve the matching post-state and observed signals. When the process disappears first, preserve the open span and process-loss boundary with a null post-state.

Negative evidence requires a declared signal, an identified active observer, a fresh source, a completed observation window, and an explicit absence. Silence from a stale log or missing observer is unknown, not negative evidence. The last marker is an execution boundary, not a cause.

Separate observation, inference, hypotheses, and proven cause. A `native_crash_confirmed` claim requires correlated external terminal evidence. After a crash, the observability gate passes only when a fresh agent who was not present can reconstruct the operation, state boundary, expected, observed, and absent signals, active span, terminal process evidence, exact head, causality status, and next decision from sanitized artifacts.

## Owned scope

- evidence classification and manifests
- exact-head and installed/loaded identity comparison
- freshness and command-correlation checks
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
- promoting a last marker, stale log silence, or process non-observation into root cause or confirmed native crash
- evidence deletion without archive or supersession proof
- committing raw logs, saves, crash dumps, credentials, tokens, private configuration, or absolute personal paths

## Validation

```powershell
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
- Crash-sensitive operations have a pre-state, post-state or process-loss boundary, declared expected signals, observed signals, valid negative evidence, and a correlated active span.
- Observation, inference, hypotheses, and proven cause are separated; confirmed native crashes have external terminal evidence.
- A fresh agent can reconstruct the failure from sanitized artifacts, or the observability gap is reported as the blocker.
- Allowed and forbidden claims are recorded.
- Retention or deletion disposition is recorded; failures needing remote review have a schema-valid sanitized capsule or an explicit reason none is required.
- No higher proof level is inferred from a lower one.
