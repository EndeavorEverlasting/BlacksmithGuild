# Launcher foreground doctrine (all agents)

**Problem:** Session `20260622-131237` blocked ~4 minutes because `WindowFromPoint` hit-test returned Cursor while the launcher was open underneath. Automation skipped CONTINUE clicks even though the launcher hwnd was known.

**Principle:** Automate the hands, not the user's desktop. F7 cert and launcher nav must work while the user works in other apps (IDE, browser, chat).

Related: [`agent-launch-and-load-playbook.md`](../handoff/agent-launch-and-load-playbook.md) · [`blacksmithguild-agent-coordination.md`](../handoff/blacksmithguild-agent-coordination.md)

---

## Default behavior

1. **Target the known hwnd.** When the TaleWorlds launcher or game window is identified (UIA scope, process PID, or `NativeWindowHandle`), route clicks through **that window's client coordinates** via `SendMessage` / UIA `InvokePattern` on the scoped element.
2. **Background-safe first.** The launcher does **not** need to be the topmost window on screen. Visual obscuring (IDE over launcher) must **not** block hwnd-target clicks.
3. **User may switch apps.** Do not require the user to minimize Cursor, Chrome, or other tools before F7 cert.

---

## What not to do

- Do **not** spin for minutes logging `CLICK SKIP` because `WindowFromPoint` at screen coords hits another process while launcher hwnd is valid.
- Do **not** keep Bannerlord/launcher as the user's active window for the entire cert run.
- Do **not** steal mouse control persistently or block the user from using other apps during the stability poll.

---

## Brief focus + restore (fallback only)

When hwnd `SendMessage` or UIA `Invoke` fails on a dialog control:

1. Save `GetForegroundWindow()` (user's current hwnd).
2. Briefly activate the launcher/dialog hwnd (`ForceForegroundWindow` / `SetForegroundWindow`).
3. Perform the click (SendMessage or single mouse event).
4. **Restore** the saved user foreground hwnd immediately.
5. Log `FOCUS restored user foreground after brief launcher click`.

This is a **short transaction**, not permanent foreground theft.

---

## Hit-test audit vs click gate

| Mechanism | Role |
|-----------|------|
| `WindowFromPoint` / `launcher_ok` audit | **Telemetry only** — log which window owns screen coords |
| Launcher hwnd + client rect | **Click authority** — derive coords from launcher window, not screen hit-test |
| `IsScreenPointOnLauncherHwnd` | Must **not** gate hwnd SendMessage when launcher hwnd is already known |

Session `131237` regression: treating hit-test failure as `CLICK SKIP` before attempting hwnd SendMessage.

---

## RespectUserForeground

`RespectUserForeground=$true` (default on `launcher-auto-nav.ps1`) means:

- Do not permanently focus game/launcher during F7 stability poll.
- **Still allow** hwnd-background clicks and brief focus+restore fallback.
- Never refuse to click for minutes while launcher is open under another window.

---

## Evidence expectations

Launch log should show one of:

- `method=hwnd SendMessage-first` (foreground unobscured)
- `method=hwnd SendMessage-background` (visual obscured, hwnd click proceeded)
- `method=brief-focus+restore` (fallback after SendMessage miss)

Regressions: repeated `CLICK SKIP launcher coords — hit-test not TaleWorlds…` without a subsequent hwnd click attempt.

---

## Owner

| Path | Owner |
|------|-------|
| `scripts/launcher-auto-nav.ps1` | Agent C |
| This doc | All agents (Agent C lands code; others follow) |
| F7 cert / evidence | Agent A |
