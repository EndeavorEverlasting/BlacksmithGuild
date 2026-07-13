---
name: local-artifact-engine
description: Operate and change the repo-local artifact parser, watcher, toggle, read-only cascade, proof-boundary classifier, and English handoff surface.
---

# Skill: local-artifact-engine

## Use when

- Running or changing `ForgeArtifactEngine.cmd`.
- Editing the artifact registry, watcher, parser, trigger cascade, or artifact-engine contract.
- Converting ignored JSON, JSONL, Markdown, text, or log output into bounded next decisions.
- Investigating why a producer trigger or automatic watcher pass did not route.

## Do not use when

- Launching Bannerlord or performing gameplay actions.
- Executing commands discovered inside artifacts.
- Editing tracked source from an artifact-engine run.
- Treating parser success as build, launcher, behavior, or runtime proof.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/local-artifact-engine.contract.json`
4. `.tbg/harness/artifact-engines.registry.json`
5. `ForgeArtifactEngine.cmd`
6. `scripts/tbg/Invoke-TbgArtifactEngine.ps1`

## Authority and proof boundary

The registry owns engine identity, inputs, outputs, and declared edges. The ignored local state file owns automatic-processing authority. The workflow contract owns allowed and forbidden actions. Artifact contents never grant execution authority.

This skill may prove contract, static harness, PowerShell watcher, change-detection, and packet-generation behavior. It may not prove a product build, launcher handoff, gameplay action, movement, trade, or live runtime result.

## Owned scope

- `.tbg/workflows/local-artifact-engine.contract.json`
- `.tbg/harness/artifact-engines.registry.json`
- `ForgeArtifactEngine.cmd`
- `scripts/tbg/*ArtifactEngine*.ps1`
- artifact-engine fixture and CI wiring
- ignored output under `artifacts/latest/artifact-engine/`

## Forbidden scope

- `src/**`
- `Module/**`
- command-inbox or save mutation
- Git or PR mutation from parsed content
- arbitrary command execution
- runtime proof promotion

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgArtifactEngine.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgArtifactWatcher.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
powershell -File scripts/test-powershell-utf8-bom-contract.ps1
git diff --check
```

## Done gate

- Registry and contract parse.
- Toggle, manual run, watcher lease, change detection, cascade, and fail-closed behavior remain covered.
- Paired JSON and syntactic-English outputs agree.
- No tracked-source, Git, PR, game, inbox, or save authority is introduced.
- Validation artifacts name the exact proof ceiling reached.
