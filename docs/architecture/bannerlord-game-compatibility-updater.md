# Bannerlord Game Compatibility Updater

`ForgeGameUpdate.cmd` is the click-first, metadata-only gate before build, launcher, or runtime certification. It observes six identities independently so an old DLL or an unnoticed game update cannot inherit proof from a different environment.

| Identity | Source | Why it stays distinct |
|---|---|---|
| Upstream available build | Steam [`ISteamApps.UpToDateCheck`](https://partner.steamgames.com/doc/webapi/isteamapps) | Detects a public build newer than the local installation. |
| Locally installed build | Steam appmanifest, Native module XML, game executable metadata | Records what this machine actually has without starting the game. |
| Repo-supported build | `.tbg/state/game-compatibility.registry.json` | States the version family the tracked source currently supports. |
| Source commit | Git exact head, branch, and dirty state | Binds compatibility evidence to source identity. |
| Built mod DLL | Repository build output hash and metadata | Distinguishes source from its local binary product. |
| Installed mod DLL | Game module hash and metadata | Detects install drift before launch. |

## Operator flow

Double-click `ForgeGameUpdate.cmd`, then read the terminal state and the retained report under `artifacts/latest/game-compatibility/`. The wrapper pauses and preserves the script exit code. `ForgeState.cmd compatibility` reads the latest result without performing a new query.

`check` queries Steam with a bounded timeout. `offline` records local identities without an upstream query. `reconcile` performs the same non-mutating observation while making the state-spine intent explicit. None of these modes installs a game update.

## State-spine integration

Every completed inspection writes:

- `TbgGameCompatibilityResult.v1` under the latest and run-specific artifact directories;
- one `TbgObservation.v1` carrying the six observed identities;
- one `TbgEvidenceRecord.v1` bounded to harness proof;
- a `game.compatibility.observed` journal event and refreshed state envelope when the repo state spine is available;
- English report, handoff, progress, and structured event artifacts.

The fixtures and `scripts/tbg/Test-TbgGameCompatibility.ps1` execute both an aligned-build path and an update-available path. CI runs this test in PowerShell Core and Windows PowerShell 5.1.

## Proof boundary

A green metadata result proves only that the observed identifiers aligned at the recorded time. It does not prove Steam completed an update, a build succeeded, the installed assembly loaded, the launcher progressed, a save loaded, or runtime behavior occurred.

Any changed or unknown upstream, installed, or repo-supported game build invalidates earlier launcher and runtime proof. After compatibility is current, build/install identity, loaded-assembly identity, command ACK, and behavior evidence must still be established in order by their authorized workflows.

The updater never launches Bannerlord, runs `ForgeReboot.cmd` or `Run-VisibleTradeProof.cmd`, builds or installs the mod, writes the command inbox, or mutates saves.
