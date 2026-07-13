---
name: launcher-lifecycle
description: Own ForgeStop-first conditions, build and deploy handoff, Bannerlord process and window lifecycle, Continue selection, timeouts, supervision, clean stop, and launcher evidence.
---

# Skill: launcher-lifecycle

## Use when

- Building or deploying immediately before a Bannerlord launch.
- Running ForgeStop, ForgeReboot, Continue selection, launcher supervision, process classification, or window selection.
- Changing launcher scripts, lifecycle timeouts, modal handling, or clean-stop behavior.
- Producing launcher-specific evidence.

## Do not use when

- Claiming gameplay correctness, route movement, arrival, buy, sell, or smithing completion.
- Editing `src/BlacksmithGuild/MapTrade/**` in a launcher-only lane.
- Launching the game when the active workflow does not grant runtime authority.
- Treating launcher handoff as campaign readiness or live runtime completion.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `ForgeStop.cmd`
4. `docs/control/logs/open/window-delta-doctrine.md`
5. `docs/handoff/runtime-state-routing.md`
6. the active launcher or reboot script and workflow

## Lifecycle boundary

Use the repo's ForgeStop path before operations that assume Bannerlord is not running. Preserve process, PID, window, timeout, modal, launch-log, and lifecycle evidence. Hand off to runtime or route skills only after the launcher-specific terminal state is explicit.

## Owned scope

- `ForgeStop.cmd` and launcher/reboot wrappers
- launcher and process-supervisor scripts
- window and modal classification
- lifecycle timeouts and clean stop
- launcher logs and lifecycle artifacts
- launcher-specific validators

## Forbidden scope

- route, trade, economy, smithing, or save behavior
- product PASS from launcher success
- command-inbox writes unless the active workflow explicitly includes them
- unrelated branch or worktree cleanup
- stale evidence presented as fresh launcher proof

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
powershell -File scripts/test-powershell-utf8-bom-contract.ps1
git diff --check
```

Run the exact launcher validator registered by the active workflow. Live launch is optional and must be explicitly authorized.

## Done gate

- Stop-first ownership is explicit.
- Build/deploy and launched binary identity are recorded when claimed.
- Process and window selection are bounded and evidenced.
- Timeout and clean-stop behavior are defined.
- Launcher proof is not promoted to gameplay proof.
