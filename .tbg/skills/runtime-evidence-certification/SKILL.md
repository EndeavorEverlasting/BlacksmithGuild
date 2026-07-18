---
name: runtime-evidence-certification
description: Classify freshness, exact-head identity, installed and loaded assemblies, command correlation, behavior evidence, proof levels, and retention before runtime claims.
---

# Skill: runtime-evidence-certification

## Use when

- A request uses words such as proved, passed, loaded, moved, arrived, traded, or worked.
- Inspecting runtime artifacts, exact-head identity, installed DLL hashes, loaded assembly identity, or command correlation.
- Deciding the highest proof level supported by fresh evidence.
- Archiving or retaining runtime evidence.

## Do not use when

- Writing product behavior as part of an evidence-only lane.
- Treating stale `Status.json`, parser success, command ACK, route assignment, or a checkpoint as completion.
- Inferring movement, arrival, or trade without numeric or visible supporting evidence.
- Deleting evidence before its owner, head, freshness, proof value, and replacement are recorded.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `docs/handoff/runtime-state-routing.md`
4. `.tbg/harness/artifact-engines.registry.json`
5. `ForgeAgentStatus.cmd`
6. the fresh runtime and artifact-engine packets named by the active workflow
7. `artifacts/latest/window-lifecycle/window-lifecycle.result.json` when present
8. `artifacts/latest/artifact-engine/window-lifecycle-boundary.result.json` when present

## Proof ladder

```text
contract -> harness -> static test -> build -> launcher -> command ACK -> behavior observed -> live runtime
```

Every result must state freshness, branch or exact head when relevant, evidence paths, allowed claims, forbidden claims, and the proof ceiling actually reached. Window-lifecycle artifacts and the `window-lifecycle-boundary` packet are correlation inputs only; they never replace live runtime evidence or promote action dispatch into product proof.

## Owned scope

- evidence classification and manifests
- exact-head and installed/loaded identity comparison
- freshness and command-correlation checks
- proof-boundary reports
- evidence retention decisions
- runtime-evidence documentation and validators

## Forbidden scope

- unrequested gameplay changes
- launcher implementation changes
- save or command-inbox mutation
- claim promotion without evidence
- evidence deletion without archive or supersession proof

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
.\ForgeAgentStatus.cmd
.\ForgeArtifactEngine.cmd run -Mode observe
git diff --check
```

Run workflow-specific build, launcher, command, movement, arrival, and trade validators only when the active contract grants that authority.

## Done gate

- The exact claim is mapped to a named proof level.
- Freshness and identity are explicit.
- Every evidence path exists or is reported missing.
- Allowed and forbidden claims are recorded.
- Retention or deletion disposition is recorded.
- No higher proof level is inferred from a lower one.
