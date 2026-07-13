---
name: operator-control-surface
description: Own toggles, hotkeys, command inbox, Manual/Assist/Autonomous mode, user-triggered events, ACK-versus-action semantics, stop and hold behavior, and English operator status.
---

# Skill: operator-control-surface

## Use when

- Adding or changing a hotkey, toggle, command, mode, stop, hold, or resume control.
- Working on Manual, Assist, or Autonomous state.
- Handling user-triggered events such as `Ctrl+Alt+T`.
- Diagnosing a command that logged an event but produced no practical action.
- Rendering concise syntactic-English operator status.

## Do not use when

- Treating a command ACK as practical action.
- Claiming movement, arrival, trade, or completion from a message-log entry.
- Editing route behavior in a control-surface-only lane.
- Bypassing authority, stop, safety, or proof gates for convenience.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `docs/handoff/runtime-state-routing.md`
4. `ForgeStop.cmd`
5. the relevant root command wrapper, command-inbox handler, and mode-state source
6. fresh `CommandAck`, `Status`, and behavior evidence

## Control sequence

```text
user input -> command accepted or rejected -> authority and mode checked -> practical action dispatched -> behavior observed or blocked -> status reported
```

The operator surface must distinguish receipt, ACK, dispatch, behavior, and completion.

## Owned scope

- root `Forge*.cmd` operator wrappers
- command-inbox and hotkey handling
- Manual/Assist/Autonomous mode state
- stop, hold, resume, and toggle behavior
- ACK and operator-status artifacts
- operator-control validators and English reporting

## Forbidden scope

- unowned route or launcher implementation
- save mutation without explicit workflow authority
- implicit game launch
- ACK promoted to behavior proof
- operator controls that silently bypass policy

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
powershell -File scripts/test-powershell-utf8-bom-contract.ps1
git diff --check
```

Also run the exact command, hotkey, mode, or inbox validator registered by the active workflow.

## Done gate

- Input, ACK, dispatch, behavior, and completion states are distinct.
- Toggle and mode authority are explicit and persistent where required.
- Stop and hold remain available and bounded.
- Status output is complete syntactic English plus machine-readable state.
- Practical action is evidenced or the blocker is named.
