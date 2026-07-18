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

## Proof modes

Post-attach automation is graded in three separate proof modes. A weaker mode passing
never implies a stronger one. The autonomous assist runner stamps the achieved mode on
`assist-loop-summary.json` as `proofMode` plus the boolean `visibleMechanicsProven`.

- `read_only_runtime_proof` - the Regent/Route/Horse/Ledger spine and governor cycle
  produced valid decision/intelligence JSON. Proves where to go and why. No mutation and
  no movement. Owned by the governor disposable smoke path.
- `attach_readiness_proof` - the game launched, the campaign attached, the surface was
  classified safe, and the assist loop started consuming runtime state. Proves the bridge
  is wired. It is NOT a movement PASS.
- `visible_mechanics_proof` - the party visibly moved on the campaign map after a command
  ack with the campaign clock running. This is the only mode that proves mechanics. It
  requires durable movement evidence (`party_movement_observed` checkpoint / movement
  proof ledger classification). `partyMovedDistance` is supporting evidence, not the sole
  verdict; route intent, a set destination, or a resumed clock alone do not qualify.

Offline enforcement of this separation lives in
`scripts\verify-post-attach-actionability-contract.ps1`.

## Shared clock-resume helper

A travel command only becomes visible mechanics when the campaign clock is running, so
every movement driver routes its `TimeControlMode` handling through one helper,
`CampaignClockResumeHelper.EnsureClockRunning(caller)`
(`src\BlacksmithGuild\DevTools\ClockResumeHelper.cs`). It only flips `Stop` to
`StoppablePlay`, never overrides user pause/fast-forward, refuses to act while a map menu
or mission surface is open, and logs the `caller` plus before/after state under
`[TBG CLOCK]`.

- Golden path: `AutoTravelService.ReassertRunningClock` delegates to the helper.
- Map-trade and guild-loop: the shared low-level mover
  `CampaignMapMovementHelper.TryMoveToSettlement` resumes the clock on every successful
  travel command, covering `MapTradeVisibleMovementDriver`, `MapTradeAutonomousService`,
  `AutonomousGuildLoopService`, and `CohesionExecutionDriver`.
- `CampaignMapMovementHelper.TryHold` deliberately does not auto-resume; holding in place
  is not a travel command.

## Focus policy

Launcher automation respects the user's foreground window by default so the operator can
keep using the machine while a session runs. Aggressive focus-steal (real foreground
clicks) is opt-in only.

- `scripts\launcher-auto-nav.ps1` defaults `RespectUserForeground = $true`. Its
  `play_escalate` / `continue_escalate` foreground-click fallback now only fires when
  `-AllowFocusSteal` is passed; otherwise it logs `*_escalate_suppressed` and stays
  hands-off.
- `scripts\run-autonomous-assist-session.ps1` and
  `scripts\run-pr11-town-travel-launch-attach-execute.ps1` default to respecting the
  foreground and forward `-AllowFocusSteal` to the child only when the operator passes it.
- `Invoke-TbgLauncherAutoNavChild` (in `scripts\autonomous-assist-session.ps1`) defaults
  `RespectUserForeground = $true` and only appends `-AllowFocusSteal` when explicitly
  requested.

Use `-AllowFocusSteal` only when an unattended machine needs the launcher to force its
window forward to complete PLAY/CONTINUE.

## Launcher Window Context doctrine

Launcher PID/window selection is a shared-context problem, not a local script preference.
The authoritative plan lives in:

- `docs/handoff/launcher-window-context-factoring.md`
- `scripts/verify-launcher-window-context-contract.ps1`

The intended spine is:

```text
S1 baseline process/window snapshot
-> S2 post-launch/request snapshot
-> compare S1/S2
-> confidence-score one candidate
-> bind preferred hwnd/pid
-> use that bound context for launcher UIA and coordinate fallback
```

Existing launcher reuse is allowed, but it must still refresh or write launcher context.
The bad pattern is skipping `open-bannerlord-launcher.ps1` merely because a launcher
process already exists and then calling `launcher-auto-nav.ps1` without a fresh or
intentionally reused context. That can leave `launcher-auto-nav.ps1` with a stale S1
artifact or a fallback baseline captured after the launcher was already present.

Future launch-adjacent scripts must obey these rules:

- no `launcher-auto-nav.ps1` call without a fresh or intentionally reused
  `LauncherWindowContext`
- no title/size heuristic coordinate selection while a valid context exists
- no PID-global UIA before trying the bound hwnd/pid context
- no `Get-Process ... | Select-Object -First 1` as launcher authority
- no silent fallback
- dialog exceptions must log why they are outside the bound launcher context
- focus helpers must not bypass context silently

This is currently a documented factoring plan, not a completed implementation refactor.
Agents should update the plan and verifier before changing launcher PID/window behavior.

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
before buy/sell. Functional output should answer where to go, why that place,
which engine voted for it, what horse/capacity/trade/food/recruitment facts
support it, and what proof is still missing before any mutation.

## Offline verification

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-governor-operator-harness-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-regent-route-horse-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-post-attach-actionability-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-launcher-window-context-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1
```

The verifiers check that smoke outputs use `.local/`, stop/focus safety is wired,
decision JSON fields are validated, the Regent/Route/Horse commands stay
registered, local-only runtime JSON remains ignored, and launcher PID/window context
principles stay visible before implementation agents touch launcher selection.
