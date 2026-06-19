# BlacksmithGuild — Checkpoint After 006J Partial Closeout

## Repo state

| Field | Value |
|-------|-------|
| Path | `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild` |
| Branch | `main` only |
| Rollback | `git checkout 006i-4-path-c-pass` (@ `57f6062`) |
| Version | `v0.0.11` |
| Remote | ahead of `origin/main` — **do not push** unless user requests |
| Open PRs | None |
| Tag `006i-live-cert-pass` | **Not created** — cert incomplete |

## Verdict

**006J PARTIAL CLOSEOUT** — infrastructure fixes shipped; live cert still open.

| Path / item | Result | Notes |
|-------------|--------|-------|
| UTF-8 BOM (PS 5.1 Forge parse) | **SHIPPED** | All `.ps1` + `scripts/tools/Add-Utf8Bom.ps1` |
| Zero-click contract doc | **SHIPPED** | `docs/forge-zero-click-contract.md` |
| Path A bootstrap (Layer B) | **PASS** (prior) | Phase1 ~02:32:04 — TBG READY, count=1 |
| Path C quit | **USER PASS** | 006I-4 |
| Layer A handoff | **FAIL** | No `handoff:` in Launch.log |
| Module Mismatch UIA | **FIXED** | Scoped to Module Mismatch dialog; no desktop `mismatch` scan |
| Desktop click safety | **FIXED** | No RootElement clicks; `ForgeStop.cmd` for emergency kill |
| Continue load | **PENDING** | Re-test `LaunchForgeContinue.cmd` |
| Path B culture Back | **PENDING** | Not re-certified |
| Market F12 | **PENDING** | `BlacksmithGuild_MarketIntel.json` absent |
| 005E smithing posse | **BLOCKED** | 006I LIVE CERT PASS |

## Shipped this sprint (agent)

1. **UTF-8 BOM** on all PowerShell scripts — fixes `launcher-auto-nav.ps1` parse failure on `Forge.cmd` (Windows PowerShell 5.1 + em-dash without BOM).
2. **`scripts/tools/Add-Utf8Bom.ps1`** — copied from SysAdminSuite; run `-Fix` after new `.ps1` files.
3. **`.editorconfig`** — `charset = utf-8-bom` for `*.ps1` / `*.psm1` / `*.psd1`.
4. **`docs/forge-zero-click-contract.md`** — canonical Play → Confirm → Safe Mode No → character build → TBG READY spec.

## Known gap — desktop click safety (FIXED 2026-06-19)

**Root cause:** `launcher-auto-nav.ps1` used `AutomationElement.RootElement` to find buttons named `PLAY`, `Yes`, `No`, `Confirm` anywhere on the desktop. That clicked unrelated apps (Excel, games, PowerShell taskbar pins, etc.).

**Fix shipped:** All UIA clicks are scoped to Bannerlord launcher/game windows or titled dialogs (`Safe Mode`, `Module Mismatch`, crash reporter, CAUTION). Global desktop fallback and `{ENTER}` SendKeys removed.

**Emergency stop:** `ForgeStop.cmd` — kills Bannerlord, launcher, and forge shell processes (no taskbar icon).

## Prior gap — Module Mismatch false positive (FIXED same commit)

`HasModuleMismatchDialog()` previously matched any UIA `Text` containing `"mismatch"` on the entire desktop. Now requires exact `"Module Mismatch"` title/text within scoped windows only.

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_MarketIntel.json
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Forge.log
```

## Key docs

- [docs/forge-zero-click-contract.md](../forge-zero-click-contract.md)
- [docs/plans/006j-full-live-cert-closeout.plan.md](../plans/006j-full-live-cert-closeout.plan.md)
- [docs/sprint-006i-live-results.md](../sprint-006i-live-results.md)
- [NEXT_STEPS.md](../../NEXT_STEPS.md)

## On full PASS (next agent)

- Tag `006i-live-cert-pass` at HEAD
- Replace this file with `post-006j-handoff.md` (PASS record)
- Create `docs/sprint-005e-m-market-intel-live-results.md`
- Update `NEXT_STEPS.md` — unblock 005E smithing posse
- Mark 006J plan SHIPPED

## Scope lock

No 005E smithing posse code, no version bump, no push, no revert 006I-4 quit fix.
