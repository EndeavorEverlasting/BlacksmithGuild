# Skill: save-compatibility

Use this skill when a task needs to discover Bannerlord saves, classify save role, compare save-file version to the installed game version, verify the approved dev-save alias pair, or decide whether an exact save may advance to launcher-lifecycle.

## Read first

1. `AGENTS.md`
2. `CODEBASE_MAP.md`
3. `.tbg/workflows/save-compatibility-classification.contract.json`
4. `.tbg/state/save-compatibility.registry.json`
5. `.tbg/harness/policies/disposable-save.policy.json`
6. `docs/operator/save-compatibility.md`

## Trigger conditions

Use when the task mentions:

- save version or save compatibility;
- newer-save/version dialogs;
- disposable/dev/test save classification;
- `saveauto*.sav` versus approved aliases;
- exact-save prelaunch gating;
- recording a newly created save's hash/version after a separately authorized runtime workflow creates it.

## Required inputs

- exact installed game version, preferably from `artifacts/latest/game-compatibility/game-compatibility.result.json`;
- explicit save path for gate mode, or no path for read-only catalog discovery;
- tracked save-role policy.

## Procedure

1. Never infer compatibility from the filename.
2. Run `ForgeSaveCompatibility.cmd` or `scripts/tbg/Invoke-TbgSaveCompatibility.ps1` in `catalog` mode for inventory.
3. Inspect the generated result/report.
4. For a proposed automatic target, run `gate` mode against that exact path.
5. Require exact save/game version match and an automation-eligible role.
6. If an approved alias is targeted, require the canonical alias pair to be present, byte-identical, and equal in parsed version.
7. Hand a passing prelaunch gate to `launcher-lifecycle`; do not load or launch from this skill.
8. After a separately authorized runtime workflow creates a save, rerun this classifier against the new file before it is reused automatically.

## Expected outputs

- `artifacts/latest/save-compatibility/save-compatibility.result.json`
- `artifacts/latest/save-compatibility/save-compatibility.report.md`
- run-local `events.jsonl`

## Proof ceiling

`real-file read-only parsing`

A passing classification proves the observed save bytes/hash/version are compatible with the exact observed game version. It does not prove Bannerlord loaded the save, campaign readiness, map traversal, governor behavior, or live runtime.

## Owned scope

- `.tbg/state/save-compatibility.registry.json`
- `.tbg/workflows/save-compatibility-classification.contract.json`
- `.tbg/harness/save-compatibility-artifacts.registry.json`
- `.tbg/harness/fixtures/save-compatibility.fixtures.json`
- `.tbg/harness/schemas/save-compatibility-result.schema.json`
- `scripts/tbg/Invoke-TbgSaveCompatibility.ps1`
- `scripts/tbg/Test-TbgSaveCompatibility.ps1`
- `docs/operator/save-compatibility.md`
- generated save-compatibility result/report artifacts

## Forbidden scope

- `.sav` mutation, copy, rename, delete, timestamp pinning, creation, or overwrite;
- Bannerlord/launcher actuation;
- modal dismissal;
- command inbox writes;
- product code changes;
- runtime proof promotion.

## Failure handling

Fail closed on unknown/ambiguous versions, newer saves, missing target saves, non-eligible roles, or approved-alias pair mismatch. An older save is attention-only and requires a separate recertification decision before automatic use.

## Handoff

A successful gate hands only these facts to launcher-lifecycle: target leaf name/path, SHA-256, parsed save version, exact game version, role, alias-pair state, and prelaunch terminal state. Launcher-lifecycle must independently prove the same save identity at the in-game load boundary.
