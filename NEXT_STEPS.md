# Next Steps

Math before hammer.

---

## Sprint sequencing

Build/install loop first. Certification evidence second. Dev-tool safety third. Skill points fourth. Recommendations later.

| Order | Sprint | Purpose | Status |
|-------|--------|---------|--------|
| 1 | **000A** | Certify in-game load / gold / hotkey chain (Tests 1–3) | **Certified** (2026-06-18) |
| 2 | **000B** | Fluid Steam dev loop (`dotnet build` auto-install, Steam Play) | **Complete** |
| 3 | **001** | Dev command harness (visible, repeatable, safe) | **Certified** (2026-06-18) |
| 3b | **001B** | Focus-aware inbox poll, explicit certification status, `-Certify -Wait` | **Certified** (2026-06-18) |
| 3c | **001U** | In-game command feedback + message-channel clarity (F7–F11 visible) | **Complete** |
| 3d | **001U-Fix** | Message timing + visibility (map readiness gate, TBG READY, no auto gold) | **Complete** |
| 4 | **002** | Stoke the Apprentice — skill-point / progression harness + F7 status | **Code complete — certify in-game** |
| 5 | **003** | Treasury Delta Watch (evidence system) | Planned — see `docs/treasury-delta-watch-*.md` |
| 6 | **004+** | Recommendation system | Later |

> **Breadcrumb:** `Ctrl+Alt+S` runs `RichSmithingProgressionTest`. **F7** = read-only status verdict card. See [docs/in-game-surfaces.md](docs/in-game-surfaces.md).

---

## Repo state (handoff for next chat)

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.5` |
| Sprint 000A | **Certified** (2026-06-18) |
| Sprint 000B | **Complete** |
| Sprint 001 / 001B | **Certified** — `certification.overall: PASS` (6/6) via `-Certify -Wait` |
| Sprint 002 | **Code complete** — progression commands wired, F7 `ShowForgeStatus`, `-CertifyProgression`; needs in-game PASS |
| Sprint 003 | **Planned** — Treasury Delta Watch (`docs/treasury-delta-watch-plan.md`) |
| Dev loop | **Steam Play** daily; close Bannerlord before `Forge.cmd` / `dotnet build` for install; watch mode can build while game is open |
| In-game surfaces | [docs/in-game-surfaces.md](docs/in-game-surfaces.md) — message feed (F7–F11), toast (forge), file logs |

**Next: Live retest Sprint 001U-Fix on disposable campaign (wait for `TBG READY`, then F7–F11). Then certify Sprint 002: `.\forge.ps1 -CertifyProgression -Wait`.**

**Dev loop:** Close Bannerlord, then **`Forge.cmd`** after code changes. **`ForgeWatch.cmd`** can rebuild while the game is open; if install is blocked, close Bannerlord and run **`Forge.cmd`** again. Watch for `TBG RELOAD` / **F7** `reload=blocked` or `reload=pending`.

### Sprint entry gates (do not skip)

| Sprint | Enter when | Do not start if |
|--------|------------|-----------------|
| **001** Dev tool safety | 000B complete; 000A Tests 2–3 PASS in log | Preflight/crash unresolved |
| **002** Progression harness | 001 certified (`certification.overall: PASS`) | Dev inbox unreliable; progression not registered |
| **003** Treasury Delta Watch | 002 certified (`certification002.overall: PASS`) | F7/surfaces not shipped; skill harness untested |
| **004+** Recommendations | 003 evidence stable | Treasury watch not proven safe |

---

## Approach (next feature)

1. **Use the repo’s existing dev-command spine.** `DevCommandRegistry`, `DevCommandRunner`, hotkeys, and test scenarios already exist. Do not bypass that. Add skill progression through the same machinery.
2. **Do not keep stacking daily-tick hacks.** Gold injection on daily tick was fine for Sprint 000; skill-point testing must be **manually triggered and repeatable**.
3. **Treat “skill points” precisely.** Bannerlord has skill XP, focus points, attribute points, and direct skill-level effects. Do not lump them together.
4. **Build recommendation logic later on top of the same test data.** Graduate `ForgeAdvisor` from fake candidates into real recommendation models (Phase 2).

---

## Sprint 001 / 001B: Dev command harness (**Certified** 2026-06-18)

**Delivered:**

- `DevCommandBus` — command received/started/result/blocked logging
- `GameReadinessService` — deferred preflight when MainHero ready
- `DevHotkeyHandler` — F8–F11 primary; Ctrl+Alt+L/D/F legacy; edge debounce
- `DevCommandFileInbox` + `forge.ps1 -Command <name>`
- Live `BlacksmithGuild_Status.json` after each command
- F11 = explicit `RichPlayerEconomyTest` (decoupled from F9)

**Certification:** `.\forge.ps1 -Certify -Wait` → `certification.overall: PASS` (6/6).

---

## Sprint 002: Progression harness + F7 status (**Code complete — certify in-game**)

**Delivered (v0.0.5):**

- Progression commands: `RichSmithingProgressionTest`, `AddSmithingXp`, `AddSmithingFocus`, `AddEnduranceAttribute`
- Hotkeys: **F7** `ShowForgeStatus`, **Ctrl+Alt+S/X/C**
- `Sprint002CertificationTracker` + `certification002` in status JSON
- `.\forge.ps1 -CertifyProgression -Wait`
- [docs/in-game-surfaces.md](docs/in-game-surfaces.md) — Enter log, Alt+` console, F7 verdict card
- `engine_integrity` scan fix (ignores preflight disclaimer)

**Certify:** disposable campaign → `.\forge.ps1 -CertifyProgression -Wait` → `.\forge.ps1 -Check -SkipInstall`; expect `certification002.overall: PASS` (4/4).

**Next sprint:** Treasury Delta Watch — see `docs/treasury-delta-watch-plan.md` (when present on branch).

---

## Cursor prompt (paste next session)

```text
Repo: EndeavorEverlasting/BlacksmithGuild

Sprint 002 code complete (v0.0.5). Certify in-game:
  .\forge.ps1 -CertifyProgression -Wait
  .\forge.ps1 -Check -SkipInstall

Then Sprint 003: Treasury Delta Watch (docs/treasury-delta-watch-plan.md).
F7 reads summarized state only — service owns scan/classify/write JSON.
```

---

## GitHub issues to create (separate tickets)

### Issue 1 — Sprint 003: Treasury Delta Watch

- Evidence system per `docs/treasury-delta-watch-plan.md`
- F7 summary extension from `status.treasuryWatch`

### Issue 2 — Sprint 004+: Forge recommendation data model

- Expand `ForgeCandidate`, scoring engine, doctrine weights

---

## Stern verdict

**Next action:** Certify Sprint 002 in-game (`-CertifyProgression -Wait`). Then Sprint 003 Treasury Delta Watch.
