# Bannerlord version-upgrade impact harness

## What this solves

`ForgeGameUpdate.cmd` tells us when Bannerlord's installed/upstream/support metadata moved. This workflow answers the next question: **what BlacksmithGuild assumptions must be repaired or re-certified because of that move?**

The result is not a generic upgrade checklist. It is a generated set of evidence-backed findings and ordered sprint candidates.

## Canonical surface

- Registry: `.tbg/state/version-upgrade-impact.registry.json`
- Workflow: `.tbg/workflows/version-upgrade-impact-probe.contract.json`
- Probe: `scripts/tbg/Invoke-TbgVersionUpgradeImpactProbe.ps1`
- Validator: `scripts/tbg/Test-TbgVersionUpgradeImpactProbe.ps1`
- Operator command: `ForgeVersionUpgradeProbe.cmd`
- Publisher: `scripts/tbg/Publish-TbgVersionUpgradeSprintPacket.ps1`
- Publisher command: `ForgeVersionUpgradePublish.cmd`
- Artifact registry: `.tbg/harness/version-upgrade-impact-artifacts.registry.json`
- Output: `artifacts/latest/version-upgrade-impact/`

## Probe families

### Candidate assembly presence

The project currently references nine Bannerlord assemblies/modules. The probe verifies that each expected candidate path exists before compile. A missing assembly is a blocker because the candidate installation/layout or project reference contract changed.

### Candidate compile

Candidate mode runs `dotnet build` against the candidate `GameFolder` with both normal and wEditor outputs redirected into the probe run directory. It never installs the mod and never writes product source.

Compiler failures retain the relative source file, compiler code, and message and route by owning lane. For example a `MapTrade` compiler failure routes to `route-visible-trade`; a `DevTools/QuickStart` failure routes to `launcher-lifecycle`.

### Dynamic binding inventory

Compile success is not enough for Harmony/reflection/string-bound calls. The probe inventories lines containing tracked binding patterns such as `HarmonyPatch`, `AccessTools`, `GetMethod`, `GetProperty`, `GetField`, `Type.GetType`, and `Assembly.GetType`.

When the game version changes, those assumptions become explicit review findings because their target can drift while the project still compiles.

### Module dependency drift

`Module/BlacksmithGuild/SubModule.xml` dependency versions are compared with the candidate Native module version. Drift becomes a packaging/version-contract sprint; the probe does not edit the manifest itself.

### Save reclassification

Every game-version change invalidates old save-compatibility admission. The next save sprint receives an exact command using the candidate version and must reclassify the intended disposable/test/real save before launcher-lifecycle may use it.

### Runtime re-certification

A changed game build invalidates version-sensitive proof for:

- exact-save load boundary;
- launcher-to-campaign continuity;
- campaign readiness;
- governor command/ACK/behavior chain;
- route-visible-trade behavior;
- loaded assembly identity.

Static/build success cannot restore those proof levels.

## Modes

### Inventory

```powershell
.\ForgeVersionUpgradeProbe.cmd -Mode inventory
```

Captures the current source assumption inventory. No candidate build is required.

### Candidate

```powershell
.\ForgeVersionUpgradeProbe.cmd -Mode candidate
```

Auto-resolves the Bannerlord root when possible, observes the exact candidate version, checks candidate assembly paths, inventories dynamic bindings, compares module versions, runs the isolated-output candidate compile, reduces findings, and creates sprint artifacts.

An explicit candidate root can be supplied when probing a side-by-side installation:

```powershell
.\ForgeVersionUpgradeProbe.cmd -Mode candidate -CandidateGameRoot 'D:\Games\Bannerlord-Candidate'
```

## Generated artifacts

The canonical result is:

`artifacts/latest/version-upgrade-impact/version-upgrade-impact.result.json`

Also generated:

- `version-upgrade-impact.report.md` — human status;
- `version-upgrade-impact.source-inventory.json` — assembly/dynamic-binding/module inventory;
- `version-upgrade-impact.sprint-packet.json` — dependency-ordered sprint contracts;
- `version-upgrade-impact.issue.md` — sanitized remote issue draft;
- `candidate-build.log` — candidate compile output when build runs.

Every sprint candidate contains:

- owner lane;
- dependency;
- mission;
- finding IDs;
- first executable command;
- expected artifact;
- completion gate.

## Remote sprint emission

The probe never creates GitHub issues by itself. CI and pre-push also have no issue-write authority.

Review the generated draft:

```powershell
.\ForgeVersionUpgradePublish.cmd
```

Publish it after review using the operator's existing `gh` authentication:

```powershell
.\ForgeVersionUpgradePublish.cmd -PublishIssue
```

The publisher checks for personal-path/secret-like content and deduplicates an already-open issue with the same baseline/candidate title before creating anything.

## Terminal interpretation

- `PASS_UPGRADE_BASELINE_INVENTORIED` — current assumptions inventoried; no candidate claim.
- `PASS_NO_ACTIONABLE_UPGRADE_GAPS` — candidate static/build probes found no actionable gaps, but runtime proof remains invalid if separately required.
- `ATTENTION_VERSION_CHANGE_REQUIRES_RECERTIFICATION` — no static blocker, but version-sensitive assumptions/save/runtime proof require owned follow-up.
- `BLOCKED_VERSION_UPGRADE_GAPS` — one or more missing-assembly or compile blockers must be repaired before promotion.

## Claims not made

This harness never claims that a new Bannerlord release is safe merely because the mod compiles. It does not launch Bannerlord, update Steam, load/create saves, install the mod, touch command inboxes, dismiss dialogs, or certify runtime behavior.
