# PR 23 / PR 25 / PR 27 Coalescence Plan

## Scope

This note explains how the active launch, runtime-authority, and duration-governance PRs fit together while they move toward `main`.

Relevant PRs:

```text
PR #25 - feat/launcher-window-context-helper
PR #23 - feat/engine-toggle-authority
PR #27 - test/duration-policy-inventory-guard
```

Product target:

```text
loaded game
  -> clear runtime state
  -> authority-aware readiness
  -> safe next command
  -> controlled automation
```

This note does not claim runtime proof. It does not authorize live certs, save mutation, or merge completion.

## Merge order recommendation

Recommended order:

```text
1. PR #25 - launcher window context helper
2. PR #23 - engine toggle authority
3. PR #27 - duration inventory guard
```

Rationale:

- PR #25 should land first because it stabilizes Forge / ForgeContinue launch handoff, launcher context creation, frozen hwnd/pid navigation, and post-handoff classification.
- PR #23 should land after launch handoff is stable because it governs runtime authority after the game is loaded or attachable.
- PR #27 should land after its local validation and PR body cleanup because it protects the next runner and runtime work from casual long-duration defaults.

If conflict pressure changes, PR #27 can land earlier as a pure guardrail, but it must stay scoped to duration governance. Do not smuggle launcher or runtime behavior into the guard PR.

## What each PR unlocks

### PR #25: launch infrastructure

PR #25 gives the project a stronger launch path:

```text
Forge / ForgeContinue
  -> explicit LaunchIntent
  -> shared launcher context
  -> frozen launcher hwnd/pid during click phase
  -> post-handoff classification
```

It clarifies:

```text
game_spawned != attach_ready
hotkeys_ready != assistive_ready
loaded_game != controlled_runtime
```

PR #25 is not the product. It gets the system to the door and asks the next correct question.

### PR #23: runtime control authority

PR #23 gives the runtime a shared authority model:

```text
Manual
Hybrid
Automation
```

Meaning:

```text
Manual    = operator control, hold, abort posture
Hybrid    = explicit-command mode
Automation = permission for higher-order engines under bounded doctrine
```

It clarifies:

```text
automation_allowed != runtime proof
mode toggled != mechanism passed
raw config boolean != runtime authority
```

PR #23 does not prove live automation. It creates the control layer future runtime work must obey.

### PR #27: duration-governance safety

PR #27 adds a repo-wide inventory guard for long-duration defaults and preserves the 30-second doctrine.

Core rule:

```text
New scripts, verifiers, CMD wrappers, launch wrappers, smoke tests, observation harnesses, and runtime probes default to 30 seconds unless explicitly approved as long-run work.
```

Longer waits require one of these patterns:

```text
AllowLongRun
LongRunReason
live_certificate
operator_approved_long_cert
manual_debug
explicit long-run
full_runtime_soak
```

The baseline inventory is intentionally a debt ledger:

```text
docs/handoff/test-duration-inventory-baseline.tsv
```

Its meaning:

```text
Existing long waits are documented debt, not approval for new long defaults.
```

The baseline is not a permission slip. New casual long waits should fail the guard.

## What each PR does not prove

### PR #25 does not prove automation

PR #25 can prove better launch selection and post-handoff classification. It cannot prove attach readiness, assistive readiness, command readiness, runtime deltas, or autonomous control.

Forbidden conclusion:

```text
ForgeContinue loaded the game, therefore automation works.
```

Correct conclusion:

```text
ForgeContinue reached a launch or post-handoff checkpoint. Runtime readiness still needs evidence.
```

### PR #23 does not prove live runtime behavior

PR #23 can prove authority surfaces exist and static contracts are wired. It cannot prove Governor, MapTrade, GuildLoop, Assistive, or file-inbox commands succeeded in a live disposable save.

Required distinction:

```text
Build PASS    = code compiled
Verifier PASS = contract text and surface are present
Runtime PASS  = live disposable-save proof
Visible PASS  = command ack + visible mechanism + fresh runtime evidence
```

### PR #27 does not refactor existing long waits

PR #27 records existing long waits and blocks undocumented new ones. It does not make old launcher, assist, dev-save, or live-cert waits compliant by itself.

Future agents must burn down the baseline deliberately. They must not point at the baseline as justification for new waits.

## How PR #27 protects PR #23 and PR #25

PR #25 creates launch and post-handoff seams where agents may be tempted to wait longer instead of classifying state.

PR #23 creates runtime authority seams where agents may be tempted to wait longer for attach, hotkeys, command ack, assistive readiness, or bounded execution.

PR #27 blocks that lazy path.

Protection rule:

```text
If a future change needs more than 30 seconds by default, it must either:
  1. become a named long-run path with AllowLongRun / LongRunReason style markers, or
  2. be documented intentionally as baseline debt with path, pattern, value, class, and reason.
```

The second option should be rare. Adding debt is not progress. It is a confession with a line number.

## Next implementation lanes after coalescence

### Lane A: post-handoff readiness bridge

Build the bridge from launch success to actionable runtime state:

```text
game_spawned
  -> post_handoff_watch
  -> hotkeys_ready / assistive_commands_ready / attach_ready / attach_blocked / operator_action_required
```

Consume existing evidence artifacts before guessing:

```text
Launch.log
BlacksmithGuild_Phase1.log
BlacksmithGuild_Status.json
RuntimeLifecycle.json
ForgeStatus.json
BlacksmithGuild_CommandAck.json
BlacksmithGuild_CommandInbox.json
ExternalStateTimeline.json
```

### Lane B: migrate runtime readers to EngineToggleAuthority

Named migration targets:

```text
CampaignRuntimeGovernor.OnCampaignTick
CampaignRuntimeGovernor.AttachProposedActivity
MapTradeAutonomousService.StartRouteNow
AutonomousGuildLoopService.StartNow
AssistReadinessEvaluator.CanAcceptAssistiveCommand
```

Rule:

```text
Higher-order engines request mode through EngineToggleAuthority.
They do not flip raw DevToolsConfig booleans directly.
```

### Lane C: safe next-command proof

After readiness is classified, prove one narrow command path:

```text
runtime ready
  -> choose one safe command
  -> send command
  -> observe ack
  -> observe visible mechanism or blocked reason
  -> refresh state
  -> write checkpoint
```

Do not jump from launch success to autonomous loop claims.

### Lane D: recursive checkpoint discipline

Preserve the recursive campaign assist doctrine:

```text
checkpoint != completion
cycle_completed != product complete
finalized_pass requires terminal evidence
```

After each checkpoint, the next cycle must recompute from fresh state unless a real terminal stop condition exists.

### Lane E: duration debt burn-down

Start with high-pain entries:

```text
1. launcher / Continue / F7 wrappers
2. autonomous assist session runner
3. reboot iteration runner
4. live cert wrappers
5. economic loop probes
```

Refactor order:

```text
make duration policy explicit
then refactor execution
then reduce baseline debt
```

Do not change gameplay behavior while doing the first duration migration.

## Required validation commands

Future agents should run the offline contract suite before claiming the coalesced branch is ready:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-test-duration-policy-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-test-duration-inventory-guard.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-launcher-window-context-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-post-attach-actionability-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-engine-toggle-authority-contract.ps1
dotnet build src\BlacksmithGuild\BlacksmithGuild.csproj -c Release
git diff --check
git status --short
```

PR-specific checks:

```powershell
# PR #25
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-launcher-window-context-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-post-attach-actionability-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-launcher-pid-baseline-diff.ps1

# PR #23
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-engine-toggle-authority-contract.ps1

# PR #27
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-test-duration-policy-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-test-duration-inventory-guard.ps1
```

## Warning

Launch success is not automation success. A loaded game is only a checkpoint. It does not prove attach readiness, hotkey readiness, assistive command readiness, authority compliance, safe next-command selection, real gameplay deltas, or terminal finalization. The product path is loaded game -> clear runtime state -> authority-aware readiness -> safe next command -> controlled automation. Anything else is a launcher win wearing an automation costume. Bad costume. No medal.
