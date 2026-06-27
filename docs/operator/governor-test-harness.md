# Governor operator smoke harness

This harness is for operator-run governor smoke checks on disposable saves. It does
not certify gameplay PASS by itself, and it must not commit live runtime evidence.

## Entry points

- `Run-Governor-Disposable-Smoke.cmd` builds/deploys, launches Bannerlord, ensures
  a disposable dev save, runs `RunCampaignGovernorCycleNow`, validates the governor
  decision JSON, and writes a local summary.
- `Run-Governor-Disposable-Smoke-SkipLaunch.cmd` attaches to an already-running
  campaign and skips build/install/launch.
- `Run-Governor-Ensure-DevSave.cmd` creates or reuses an approved disposable dev
  save.
- `ForgeStop.cmd` requests a soft stop by default. Emergency force-kill is an
  explicit choice.

## Output locations

All harness outputs are local-only:

- `.local/governor-smoke/<sessionId>/governor-smoke-summary.json`
- `.local/governor-smoke/<sessionId>/BlacksmithGuild_CampaignGovernorDecision.json`
- `.local/operator-stop/forge-stop-requested.json`

The Regent/Route/Horse read-only spine may also write local runtime evidence at
the configured Bannerlord output root:

- `BlacksmithGuild_RuntimeRegent.json`
- `BlacksmithGuild_RouteCouncil.json`
- `BlacksmithGuild_HorseAtlas.json`
- `BlacksmithGuild_HerdLedger.json`

The `.local/` tree is ignored and must not be committed.

## Classifications

The scripts use these final classifications:

- `PASS` - offline governor decision contract passed for a fresh run.
- `FAIL` - script or decision contract failed.
- `BLOCKED` - setup is incomplete, for example no disposable save exists.
- `ENVIRONMENT BLOCKED` - launcher/window focus or local runtime access prevents a
  valid run.
- `USER CANCELLED` - the operator selected cancel or pressed Forge Stop.

## Create a disposable dev save

Approved disposable save names are:

- `BlacksmithGuild_DevStart*.sav`
- `BlacksmithGuild_Disposable_*.sav`
- `TBG_Disposable_*.sav`

If no approved save exists, the harness defaults to cancel and offers to bootstrap
a new campaign. The in-game command `SaveDevStartSaveNow` refuses to save unless a
campaign session is ready and the target name uses the fixed
`BlacksmithGuild_DevStart` prefix.

## Launcher focus safety

The operator launch wrapper sets `TBG_OPERATOR_INTERACTIVE_FOCUS=1`. If launcher
guarded clicks are repeatedly denied, `launcher-auto-nav.ps1` pauses and asks the
operator to bring the Bannerlord launcher to the front. Press `C` to cancel.

This is transparent operator intent, not log suppression. Normal OS, endpoint,
application, and audit logging may occur.

## Stop behavior

`ForgeStop.cmd` defaults to soft stop:

1. write `.local/operator-stop/forge-stop-requested.json`
2. send pause/abort file-inbox commands when a Bannerlord root can be resolved
3. terminate matching automation PowerShell shells

Use force-kill only for emergencies; it explicitly terminates Bannerlord and the
launcher.

## Regent / Route / Horse spine

The Governor should not blindly choose activity. The read-only strategy spine is:

1. The Regent classifies runtime state and recovery posture.
2. The Route Council compares route votes and vetoes.
3. The Horse Atlas ranks horse-market destinations before travel.
4. The Herd Ledger forecasts pack, mount, capacity, and gold posture.

These systems expose diagnostic commands such as `ShowRuntimeRegentState`,
`ConveneRouteCouncil`, `ScanHorseAtlas`, and `AnalyzeHerdLedger`. They produce
evidence only; inventory, gold, travel, and autonomous execution remain guarded
by the existing governor gates. When bounded execution is disabled, the Governor
should still surface the exact next action in its decision/activity result, for
example `ScanHorseAtlas`, `AnalyzeHerdLedger`, or local horse-market verification
before buy/sell.

## Offline verification

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-governor-operator-harness-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-regent-route-horse-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1
```

The verifiers check that smoke outputs use `.local/`, stop/focus safety is wired,
decision JSON fields are validated, the Regent/Route/Horse commands stay
registered, and local-only runtime JSON remains ignored.