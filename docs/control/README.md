# Sprint control (living pointer)

**Branch:** `fix/f7-gate-stability` @ `bbd6081` (PR [#7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7))  
**Gate:** RED — no F7 PASS manifest yet  
**Authority:** [`f7-agent-coordination.md`](../handoff/f7-agent-coordination.md)

## Active sprint

| Phase | Owner | Status |
|-------|-------|--------|
| Commit session `20260622-131237` FAIL evidence | Agent A | DONE (see evidence path) |
| Launcher foreground doctrine + hwnd-background clicks | Agent C | DONE (this sprint) |
| Clean F7 cert rerun (`HookMask 0x0F`) | Agent A | **NEXT** — requires game |
| PR #7 merge | Agent A | HOLD until manifest PASS |
| PR #8 | All | HOLD |

## Commands (preflight)

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
git checkout fix/f7-gate-stability
git pull origin fix/f7-gate-stability
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-f7-runner-contract.ps1
```

## F7 cert (after launcher fix)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F
```

Judge: exit 0 without `manifest.json` `passFail=PASS` and `stableSeconds>=60` is forgery.

## Key docs

- [`f7-agent-coordination.md`](../handoff/f7-agent-coordination.md)
- [`launcher-foreground-doctrine.md`](../conventions/launcher-foreground-doctrine.md)
- [`agent-launch-and-load-playbook.md`](../handoff/agent-launch-and-load-playbook.md)

## Latest evidence

`docs/evidence/live-cert/20260622-131237/checkpoint-01-f7-gate/manifest.json` — FAIL (contaminated cert)
