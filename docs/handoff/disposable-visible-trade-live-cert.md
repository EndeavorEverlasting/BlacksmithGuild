# Local-agent handoff: disposable visible trade live certification

## Mission

Prove on the real local Bannerlord installation that the current clean `main` can get through the already-canonical version, save, launcher, campaign-readiness, and command-acknowledgement gates and perform a real visible in-game purchase.

The terminal success state is:

`PASS_DISPOSABLE_VISIBLE_TRADE_LIVE_CERT`

This is not a prompt-only exercise. The local agent owns diagnosis and bounded implementation repairs discovered by the cert, followed by validation, commit/push/PR/merge when appropriate, return to clean `main`, and a final live-cert rerun.

## Source of truth

Repository: `EndeavorEverlasting/BlacksmithGuild`

Canonical branch: `main`

Primary operator command: `ForgeDisposableTradeCert.cmd`

Live wrapper: `scripts/tbg/Invoke-TbgDisposableTradeLiveCert.ps1`

Existing real runtime coordinator: `scripts/run-visible-trade-proof.ps1`

Canonical version authority: `.tbg/state/game-compatibility.registry.json`

Canonical save gate: `scripts/tbg/Invoke-TbgSaveCompatibility.ps1`

Disposable registry/updater: `.tbg/state/disposable-save.registry.json` and `scripts/tbg/Update-TbgDisposableSaveRegistry.ps1`

## Proof contract

A PASS requires all of the following in one certifying run:

1. checked-out branch is exactly `main`;
2. tracked worktree is clean;
3. version-authority static validator passes;
4. disposable-save contract validator passes;
5. an active disposable pin exists or a fresh TBG-owned disposable clone is created from an already exact-version eligible source;
6. the pinned save bytes pass `PASS_SAVE_VERSION_EXACT` and are automation eligible;
7. visible-trade coordinator runs without `-Diagnostic`, `-SkipBuild`, `-SkipLaunch`, or `-DryRun`;
8. exact source head is preserved through build/install proof;
9. launcher and campaign-readiness gates pass;
10. correlated command acknowledgement is observed;
11. real campaign movement is observed;
12. target settlement arrival is observed;
13. a real visible purchase is observed with `inventoryDelta > 0` and `goldDelta < 0`;
14. `artifacts/latest/visible-trade-proof.result.json` reports `PASS_VISIBLE_TRADE_PROVEN`;
15. `artifacts/latest/disposable-trade-live-cert/result.json` reports `PASS_DISPOSABLE_VISIBLE_TRADE_LIVE_CERT`.

Separate Sell-priority behavior is not part of this certificate. The existing visible-trade coordinator currently records sell from the buy delta and therefore cannot truthfully certify a separate sell. Do not promote that field into the PASS contract without independent sell evidence.

## Initial local execution

From any PowerShell terminal:

```powershell
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild'
Set-Location $repo

git fetch origin main
git switch main
git pull --ff-only origin main
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

git status --short
if (git status --porcelain) { throw 'Worktree must be clean before certification.' }

.\ForgeTest.cmd run --profile default-static --no-pause
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

.\ForgeDisposableTradeCert.cmd
exit $LASTEXITCODE
```

Do not add manual launcher/save/version sidequests before running the canonical command. The wrapper already composes those authorities.

## Repair loop if the first run fails

Read, in this order:

1. `artifacts/latest/disposable-trade-live-cert/result.json`
2. `artifacts/latest/disposable-trade-live-cert/report.md`
3. `artifacts/latest/visible-trade-proof.result.json`
4. `artifacts/latest/visible-trade-proof.handoff.md`
5. `artifacts/latest/visible-trade-proof.progress.log`
6. the newest run under `artifacts/latest/visible-trade-proof/`

Classify the first unproven gate and repair only that owner lane.

### If blocked by repository cleanliness or branch state

Preserve unrelated work. Do not reset, clean, stash, delete, or force-push it. Use an isolated worktree or finish/preserve the existing work before returning to clean `main`.

### If blocked by version authority or installed-game drift

Run the existing compatibility/version-upgrade path. Do not hard-code a new Bannerlord version into a consumer merely to pass the cert.

```powershell
.\ForgeGameUpdate.cmd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
.\ForgeVersionUpgradeProbe.cmd
exit $LASTEXITCODE
```

Use the generated version-upgrade impact packet to implement only the proven compatibility changes. After merge, return to clean `main` and rerun the cert.

### If blocked by save compatibility

Run:

```powershell
.\ForgeSaveCompatibility.cmd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\tbg\Update-TbgDisposableSaveRegistry.ps1 -CreateOwned
```

Never mutate a personal/non-disposable save and never use filename age or naming as version proof.

### If blocked by launcher, campaign readiness, command ACK, movement, arrival, or buy proof

Treat `scripts/run-visible-trade-proof.ps1` and its existing helpers/contracts as the owner. Reuse existing event, lifecycle, runtime-context, governor, MapTrade, and evidence patterns before adding anything new.

Do not bypass a failed proof gate by weakening the reducer or changing a required terminal state. Fix the producer/implementation or the harness defect that made truthful proof impossible.

## Implementation discipline

For every code/harness repair:

```powershell
git status --short
git branch --show-current
git log --oneline --decorate -5
```

Create an isolated branch/worktree when main is not safe to modify. Keep scope to the first failed owner lane. Run targeted validation, then broader static/build gates. Commit and push. Open/update a PR. Merge only after exact-head checks are green. Then return to clean `main` and rerun `ForgeDisposableTradeCert.cmd`.

Do not claim completion from a launcher click, process start, command dispatch, ACK, or stale artifact. The certificate terminates only on observed gameplay deltas.

## Required final evidence

The final local-agent report must include:

- exact `main` commit SHA used for the passing live run;
- clean `git status --short` before certification;
- build/install DLL hash match from visible-trade proof;
- disposable save leaf name and exact-version gate state;
- visible-trade run ID;
- command ACK evidence;
- movement evidence;
- settlement arrival evidence;
- purchased item ID;
- inventory delta;
- gold delta;
- `PASS_VISIBLE_TRADE_PROVEN`;
- `PASS_DISPOSABLE_VISIBLE_TRADE_LIVE_CERT`;
- artifact paths;
- any repair PR(s) merged during the loop;
- final git status.

The game may remain running for player takeover when the existing coordinator leaves it healthy. Do not terminate an active human-owned or ambiguous Bannerlord session merely to make cleanup look tidy.
