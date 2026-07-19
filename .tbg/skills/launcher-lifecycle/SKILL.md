---
name: launcher-lifecycle
description: Own ForgeStop-first conditions, build and deploy handoff, Bannerlord process and window lifecycle, ForgeContinue, Auto Launch Nav, new-game Play, Steam-mediated launch, metadata-first window identity, calibration and modal observations, timeouts, supervision, clean stop, and launcher evidence.
---

# Skill: launcher-lifecycle

## Use when

- Building or deploying immediately before a Bannerlord launch.
- Running ForgeStop, ForgeReboot, ForgeContinue, Auto Launch Nav, new-game Play, Steam-mediated launch, launcher supervision, process classification, or window selection.
- Changing launcher scripts, lifecycle timeouts, calibration handling, modal handling, metadata parsing, learned window aliases, or clean-stop behavior.
- Producing launcher-specific evidence.
- Starting or inspecting the registered external runtime observer when explicitly authorized by its read-only capability.
- Compose with `window-lifecycle-runtime` when interpreting reduced lifecycle state, quarantine, or action-dispatch proof boundaries.

## Do not use when

- Claiming gameplay correctness, route movement, arrival, buy, sell, or smithing completion.
- Editing `src/BlacksmithGuild/MapTrade/**` in a launcher-only lane.
- Launching the game when the active workflow does not grant runtime authority.
- Treating launcher handoff as campaign readiness or live runtime completion.
- Adding an image parser before process, HWND, Win32, UI Automation, dependency, context, and delta metadata have been exhausted.
- Reopening PLAY-versus-CONTINUE selection after `launcher-window-context.json` has frozen the intent.
- Treating one launch entrypoint as a safety exception to the shared observer, identity, quarantine, multitasking, event, artifact, or proof contract.
- Automatically clicking, focusing, closing, or otherwise interacting with Steam; Steam is observation-only when correlated to the active launch.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/runtime-context-continuity.contract.json`
4. `ForgeStop.cmd`
5. `.tbg/workflows/window-metadata-intelligence.contract.json`
6. `.tbg/harness/policies/window-intelligence.policy.json`
7. `.tbg/harness/window-identities.registry.json`
8. `.tbg/harness/fixtures/window-intelligence/unified-launch-surface-doctrine.fixture.json`
9. `docs/architecture/window-metadata-intelligence.md`
10. `docs/control/logs/open/window-delta-doctrine.md`
11. `docs/handoff/runtime-state-routing.md`
12. the active launcher or reboot script and workflow

## Current best strategy

Every path uses the same observer-first contract:

```text
ForgeContinue | Auto Launch Nav | new-game Play | Steam-mediated | future registered path
  -> shared run context and correlation
  -> window and external runtime observers active before actuation
  -> record every correlated top-level launch surface
  -> resolve or quarantine identity
  -> freeze exact identity per surface operation
  -> authorize or block exact semantic action
  -> dispatch or skip
  -> verify fresh transition or report unverified
  -> launcher handoff or blocked result
```

Within that contract, use this recognition order:

```text
codified process names and runtime-context ownership classification
  -> exact cached fingerprint
  -> tracked window registry metadata
  -> launcher-window-context launch intent
  -> module dependency prediction
  -> one-time S1/S2 delta discovery
  -> image or operator diagnostic only
```

`launcher-window-context.json` is the sole authority for PLAY versus CONTINUE. Before launch or stop, classify any existing canonical Bannerlord process as absent, active-owned, active-human, active-foreign, stale-or-zombie-proven, or ambiguous. Process presence is not cleanup authority. PID delta is secondary correlation only for a child launched by the current owned workflow.

The watcher records Play/Continue, calibration, Safe Mode, dependency Caution, other launcher windows, correlated Steam broker windows, and the Singleplayer handoff. Safe Mode uses the exact `No` control. Caution uses the exact `Confirm` control. Calibration remains observation-only until its exact semantic action and fixture are registered. Steam remains observation-only and may be included only when fresh launch correlation is proven; unrelated Steam windows are outside scope.

`start-runtime-observer` starts only the harness-owned observer lease. `stop-owned-runtime-observer` may revoke that lease and must never stop Bannerlord. Observer status is diagnostic evidence, not a restart or cleanup instruction.

Before proposing another launcher collector, longer timeout, coordinate map, or screenshot parser, run:

```powershell
.\ForgeWindowIntel.cmd status
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgUnifiedLaunchSurfaceDoctrine.ps1
```

## Lifecycle boundary

Use the runtime-context continuity contract before operations that assume Bannerlord is not running. Use ForgeStop only when the active workflow owns the session, stale-or-zombie state is proven, or the operator explicitly requests stop. Never terminate an active human, foreign, or ambiguous session.

Preserve the launch path, run and correlation IDs, process name, PID, HWND, executable path, title, class, control, semantic text, dependency, timeout, modal, calibration, Steam-broker, launch-log, action-lease, observer-health, and transition-verification evidence. Interpret reduced window-lifecycle artifacts through `window-lifecycle-runtime`. Hand off to runtime or route skills only after the launcher-specific terminal state is explicit.

## Owned scope

- `ForgeStop.cmd` and launcher/reboot wrappers
- `ForgeWindowIntel.cmd`
- ForgeContinue, Auto Launch Nav, new-game Play, Steam-mediated, and future registered launch-path integration
- launcher and process-supervisor scripts
- window identity registry and learned local aliases
- Win32 and UI Automation metadata parsing
- module dependency comparison
- first-seen window delta learning
- exact registered modal actions
- calibration and Steam-broker observation contracts
- lifecycle timeouts and clean stop
- launcher logs, runtime-observer events, and state-journal observations
- launcher-specific validators
- composition with `window-lifecycle-runtime` for reduced lifecycle state

## Forbidden scope

- route, trade, economy, smithing, or save behavior
- product PASS from launcher success
- command-inbox writes unless the active workflow explicitly includes them
- unrelated branch or worktree cleanup
- stale evidence presented as fresh launcher proof
- automatic action against an unknown, calibration, or Steam window
- treating process presence as zombie proof or stopping an active human, foreign, or ambiguous session
- process-memory scraping
- coordinate learning as semantic identity
- guessing PLAY versus CONTINUE from stale evidence
- path-specific bypass of observer-first startup, identity freeze, quarantine, mouse independence, event emission, artifact registration, or transition verification
- global enumeration of unrelated Steam windows

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgUnifiedLaunchSurfaceDoctrine.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgRuntimeContextContinuity.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgWindowIntelligence.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgWindowEventListener.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
powershell -File scripts/test-powershell-utf8-bom-contract.ps1
git diff --check
```

Run the exact launcher validator registered by the active workflow. Live launch is optional and must be explicitly authorized.

## Done gate

- ForgeContinue, Auto Launch Nav, new-game Play, Steam-mediated, and future paths use the same run context, observers, event cascade, artifact registry, and proof boundary.
- Observers are active before the first actuation.
- PLAY versus CONTINUE comes from the frozen launcher context.
- Play/Continue, calibration, Safe Mode, Caution, correlated Steam broker, other launcher windows, and Singleplayer handoff are all recorded.
- Known windows resolve through the registry or revalidated cache before delta or pixel fallback.
- Unknown windows produce learning candidates and receive no automatic action.
- Calibration receives no action until an exact semantic contract and fixture exist.
- Steam receives observation-only treatment and no action authority.
- Modal action authority requires direct metadata signals and an exact target HWND.
- Identity is frozen independently for each surface operation and cannot silently drift after broad rescans.
- Process and window selection are bounded and evidenced.
- Dispatch is separated from fresh transition verification.
- Timeout and clean-stop behavior are defined.
- Launcher proof is not promoted to gameplay proof.
