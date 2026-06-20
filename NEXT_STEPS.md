# Next Steps

**Daily dev:** `Forge.cmd` should zero-click to map — full contract in [docs/forge-zero-click-contract.md](docs/forge-zero-click-contract.md). Live cert steps: [docs/sprint-006e-live-cert-runbook.md](docs/sprint-006e-live-cert-runbook.md).

005E economics is next but **gated on 006I live cert PASS**. Do not start 005E until Paths A/B/C + load paths pass.

---

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS. Do not regress narrative/bootstrap. |
| 006I hotfix | Partial PASS. Disarm fix and count=1 OnActivate skip confirmed. |
| 006I-2 | SHIPPED. Launcher handoff cert pending. |
| 006I-3 | SHIPPED. Path B culture Back pending re-cert. |
| 006I-4 | **Path C USER PASS** (2026-06-19). Tag `006i-4-path-c-pass` @ `57f6062`. |
| 006I-5 | SHIPPED — Module Mismatch UIA, Continue entrypoint, load stall watchdog. Re-cert PENDING. |
| 005E market intel (read-only) | **SHIPPED** — F12 hotkey MVP; user cert PENDING |
| 005E smithing posse automation | BLOCKED (006I cert) |

**2026-06-19:** UTF-8 BOM fix shipped (Forge.cmd parse on PS 5.1). Zero-click contract documented. **UIA desktop click safety fix** — scoped clicks only; use **`ForgeStop.cmd`** if automation runs away. **Cert still PARTIAL** — see [post-006j-partial-handoff.md](docs/checkpoints/post-006j-partial-handoff.md).

---

## Active stabilization gate

006I-5 shipped fixes for Continue load hang. User re-cert required before full PASS.

Current blockers (006J):

- Layer A launcher handoff: **FAIL** — Launch.log shows timeouts; no `handoff:` line
- Continue load: 006I-5 fix shipped; **not re-tested** — need `clicked Module Mismatch Yes` in Launch.log
- Path B culture Back: not re-certified after 006I-4
- Market F12 (005E-M): **not run** — `BlacksmithGuild_MarketIntel.json` absent

Plans:

- [006I-5 Continue / Module Mismatch / Load Watchdog](docs/plans/006i-5-continue-module-mismatch-load.plan.md)
- [006I-4 Quit-to-Main-Menu Intro Replay Loop](docs/plans/006i-4-quit-to-menu-intro-loop.plan.md) — Path C PASS
- [005E Market Intelligence Shop Hotkey](docs/plans/005e-market-intelligence-shop-hotkey.plan.md) — **SHIPPED (MVP)**
- [005E Smithing Posse Stamina & Output Automation](docs/plans/005e-smithing-posse-stamina-output.plan.md) — BLOCKED

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` |
| Rollback | `git checkout 006i-4-path-c-pass` |
| Version | `v0.0.11` |
| Remote sync | ahead of `origin/main` — push when user requests |
| Open sprint | [docs/sprint-006i-live-results.md](docs/sprint-006i-live-results.md) |
| Handoff | [docs/checkpoints/post-006j-partial-handoff.md](docs/checkpoints/post-006j-partial-handoff.md) (active until 006J PASS) |
| Open sprint plan | [docs/plans/006j-full-live-cert-closeout.plan.md](docs/plans/006j-full-live-cert-closeout.plan.md) |
| Next feature | **005E** — gated on 006I cert |
| Open PRs | None |

---

## Next actions (user) — 006J cert walkthrough

**Before anything:** close unrelated apps (Excel, other games). If Forge misbehaves: **`ForgeStop.cmd`**.

**Suggested order** (easiest first):

| Step | What | When |
|------|------|------|
| **1** | `.\Forge.cmd` | Wait until campaign map (`TBG READY` in Phase1.log) |
| **4** | Press **F12** on map near a town | Same session as step 1 — do **before** closing the game |
| **2** | Close game fully → `.\LaunchForgeContinue.cmd` | Loads your dev save |
| **3** | Close game → `.\Forge.cmd` again | Culture Back test (see below) |

After all steps: **`.\CollectCertLogs.cmd`** — copies log tails into one paste block.

---

### Step 1 — Bootstrap (zero-click)

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\Forge.cmd
```

Sit back. Forge builds, opens the launcher, clicks PLAY, handles dialogs, auto-builds character, lands on map.

**Done when:** Phase1.log contains `TBG READY`.

**If wrong apps open:** `ForgeStop.cmd`, then check `BlacksmithGuild_Launch.log` for lines starting with `UIA: CLICK` — every click is logged with window title + process name.

---

### Step 2 — Continue load

Close Bannerlord completely (not just pause — exit to desktop).

```powershell
.\LaunchForgeContinue.cmd
```

**Done when:** map loads without a 5-minute hang. Launch.log should contain `clicked Module Mismatch Yes` (if that dialog appeared).

---

### Step 3 — Path B: culture Back (new to you)

This checks that pressing **Back** during character creation does **not** replay the long opening campaign video.

1. Close the game completely.
2. Run **`.\Forge.cmd`** again (starts a **new** sandbox game — that is intentional).
3. Wait. Forge auto-advances until you see the **culture / origin** screen (pick your culture).
4. **You** press **Back** or **Escape** once on that screen.
5. **PASS:** you stay in character creation — the full intro cutscene does **not** start over.
6. **FAIL:** the long opening video plays again from the beginning.

You do not need to finish the game — quit after you see PASS or FAIL. The logs record what happened.

---

### Step 4 — Market F12 (new to you)

Do this **on the campaign map** while the game is still running (easiest right after step 1).

1. On the map, click a **town** and enter it, **or** stand with your party next to a town on the world map.
2. Press **F12** once (fallback: **Ctrl+Alt+M**).
3. **PASS:** text appears in the in-game feed (bottom-left) about trade/market; Phase1.log gets `TBG REPORT: MARKET INTEL`; file `BlacksmithGuild_MarketIntel.json` appears in the Bannerlord folder.
4. **FAIL:** nothing happens, or message says map not ready — move closer to a town and try again.

Optional: press **F7** on the map for status after F12.

---

### Collect logs (paste to next agent)

```powershell
.\CollectCertLogs.cmd
```

Or manually:

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 220
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log" -Tail 120
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_MarketIntel.json"
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json"
```

**Launch.log audit keywords:** `UIA: CLICK`, `UIA: FOCUS`, `UIA: AUDIT`, `handoff:`, `ForgeStop:`

**005E — Blocked until 006I cert PASS.**

---

## Rollback

```powershell
git checkout 006i-4-path-c-pass
```

Do not revert 006I-4 quit fix unless explicitly rolling back.
