---
name: launcher-lifecycle
description: Own ForgeStop-first conditions, build and deploy handoff, Bannerlord process and window lifecycle, Continue selection, metadata-first window identity, modal actions, timeouts, supervision, clean stop, and launcher evidence.
---

# Skill: launcher-lifecycle

## Use when

- Building or deploying immediately before a Bannerlord launch.
- Running ForgeStop, ForgeReboot, Continue selection, launcher supervision, process classification, or window selection.
- Changing launcher scripts, lifecycle timeouts, modal handling, metadata parsing, learned window aliases, or clean-stop behavior.
- Producing launcher-specific evidence.
- Compose with `window-lifecycle-runtime` when interpreting reduced lifecycle state, quarantine, or action-dispatch proof boundaries.

## Do not use when

- Claiming gameplay correctness, route movement, arrival, buy, sell, or smithing completion.
- Editing `src/BlacksmithGuild/MapTrade/**` in a launcher-only lane.
- Launching the game when the active workflow does not grant runtime authority.
- Treating launcher handoff as campaign readiness or live runtime completion.
- Adding an image parser before process, HWND, Win32, UI Automation, dependency, context, and delta metadata have been exhausted.
- Reopening PLAY-versus-CONTINUE selection after `launcher-window-context.json` has frozen the intent.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/runtime-context-continuity.contract.json`
4. `ForgeStop.cmd`
5. `.tbg/workflows/window-metadata-intelligence.contract.json`
6. `.tbg/harness/policies/window-intelligence.policy.json`
7. `.tbg/harness/window-identities.registry.json`
8. `docs/architecture/window-metadata-intelligence.md`
9. `docs/control/logs/open/window-delta-doctrine.md`
10. `docs/handoff/runtime-state-routing.md`
11. the active launcher or reboot script and workflow

## Current best strategy

Use this order:

```text
codified process names and runtime-context ownership classification
  -> exact cached fingerprint
  -> tracked window registry metadata
  -> launcher-window-context launch intent
  -> module dependency prediction
  -> one-time S1/S2 delta discovery
  -> image or operator diagnostic only
```

`launcher-window-context.json` is the sole authority for PLAY versus CONTINUE. Before launch or stop, classify any existing canonical Bannerlord process as absent, active-owned, active-human, active-foreign, stale-or-zombie-proven, or ambiguous. Process presence is not cleanup authority. PID delta is secondary correlation only for a child launched by the current owned workflow. The window-intelligence watcher handles known CAUTION and Safe Mode identities through exact named controls.

Before proposing another launcher collector, longer timeout, coordinate map, or screenshot parser, run:

```powershell
.\ForgeWindowIntel.cmd status
```

## Lifecycle boundary

Use the runtime-context continuity contract before operations that assume Bannerlord is not running. Use ForgeStop only when the active workflow owns the session, stale-or-zombie state is proven, or the operator explicitly requests stop. Never terminate an active human, foreign, or ambiguous session. Preserve process, PID, HWND, title, class, control, semantic text, dependency, timeout, modal, launch-log, and action-lease evidence. Interpret reduced window-lifecycle artifacts through `window-lifecycle-runtime`. Hand off to runtime or route skills only after the launcher-specific terminal state is explicit.

## Owned scope

- `ForgeStop.cmd` and launcher/reboot wrappers
- `ForgeWindowIntel.cmd`
- launcher and process-supervisor scripts
- window identity registry and learned local aliases
- Win32 and UI Automation metadata parsing
- module dependency comparison
- first-seen window delta learning
- exact registered modal actions
- lifecycle timeouts and clean stop
- launcher logs and state-journal observations
- launcher-specific validators
- composition with `window-lifecycle-runtime` for reduced lifecycle state

## Forbidden scope

- route, trade, economy, smithing, or save behavior
- product PASS from launcher success
- command-inbox writes unless the active workflow explicitly includes them
- unrelated branch or worktree cleanup
- stale evidence presented as fresh launcher proof
- automatic action against an unknown window
- treating process presence as zombie proof or stopping an active human, foreign, or ambiguous session
- process-memory scraping
- coordinate learning as semantic identity
- guessing PLAY versus CONTINUE from stale evidence

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgRuntimeContextContinuity.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgWindowIntelligence.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
powershell -File scripts/test-powershell-utf8-bom-contract.ps1
git diff --check
```

Run the exact launcher validator registered by the active workflow. Live launch is optional and must be explicitly authorized.

## Done gate

- Existing-session classification and process-mutation ownership are explicit before stop-first behavior.
- Build/deploy and launched binary identity are recorded when claimed.
- PLAY versus CONTINUE comes from the frozen launcher context.
- Known windows resolve through the registry or revalidated cache before delta or pixel fallback.
- Unknown windows produce learning candidates and receive no automatic action.
- Modal action authority requires direct metadata signals and an exact target HWND.
- Process and window selection are bounded and evidenced.
- Timeout and clean-stop behavior are defined.
- Launcher proof is not promoted to gameplay proof.
