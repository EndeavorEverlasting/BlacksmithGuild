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
| 3c | **001U** | In-game command feedback + message-channel clarity (F7–F11 visible) | **Live certified** (2026-06-18) |
| 3d | **001U-Fix** | Message timing + visibility (map readiness gate, TBG READY, no auto gold) | **Live certified** (2026-06-18) |
| 3e | **001U-Debug** | Hotkey polling trace + menu/fallback fixes | **Live certified** (2026-06-18) |
| 4 | **002** | Stoke the Apprentice — skill-point / progression harness + F7 status | **Live certified** (2026-06-18) |
| 5 | **003** | Treasury Delta Watch (evidence system) | **003B hardened** — machinery certified; F10 retest for deltas |
| 5b | **003B** | Treasury hardening (defer snapshot, gen, JSON, dev cmd) | **Shipped** — verify with F10 |
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
| Sprint 001U / Fix / Debug | **Live certified** (2026-06-18) — see [docs/sprint-001u-live-results.md](docs/sprint-001u-live-results.md) |
| Sprint 002 | **Live certified** (2026-06-18) — `certification002.overall: PASS` (4/4) — [docs/sprint-002-live-results.md](docs/sprint-002-live-results.md) |
| Sprint 003 | **003B shipped** — [docs/sprint-003-live-results.md](docs/sprint-003-live-results.md); retest with F10/natural days |
| Dev loop | **Steam Play** daily; close Bannerlord before `Forge.cmd` / `dotnet build` for install; **`ForgeAndLaunch.cmd`** on clean PASS opens launcher |
| In-game surfaces | [docs/in-game-surfaces.md](docs/in-game-surfaces.md) — message feed (F7–F11), toast (forge), file logs |

**Next: 003B retest** — close Bannerlord, `Forge.cmd`, load disposable save, **F10** 3–5 days (not F9 alone), F7 + `TreasurySnapshotNow`, inspect JSON.

**Dev loop:** Close Bannerlord, then **`Forge.cmd`**. **`ForgeAndLaunch.cmd`** opens launcher on clean PASS only.

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

## Sprint 002: Progression harness + F7 status (**Live certified** 2026-06-18)

**Evidence:** [docs/sprint-002-live-results.md](docs/sprint-002-live-results.md)

**Certification:** `.\forge.ps1 -CertifyProgression -Wait` → `certification002.overall: PASS` (4/4).

---

## Sprint 003: Treasury Delta Watch (**003B shipped**)

**Evidence:** [docs/sprint-003-live-results.md](docs/sprint-003-live-results.md)

**003B delivered:** deferred post-tick snapshots, `snapshotGeneration`, `latestSnapshots[]` in JSON, `TreasurySnapshotNow` inbox command.

**Retest:** F10 fast-forward 3–5 days (F9 alone does not advance calendar). `.\forge.ps1 -Command TreasurySnapshotNow -Wait`.

**Next sprint (004):** Forge recommendation data model — gated on 003B retest PASS.

---

## Cursor prompt (paste next session)

```text
Repo: EndeavorEverlasting/BlacksmithGuild

Sprint 003B shipped. Retest treasury watch:
  Close Bannerlord → Forge.cmd → load disposable save
  F10 ON (3-5 days) → F10 OFF → F7
  .\forge.ps1 -Command TreasurySnapshotNow -Wait

Evidence: docs/sprint-003-live-results.md
Then Sprint 004 recommendation model.
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

**Next action:** 003B retest with F10 (not F9 alone). Then Sprint 004 recommendation model.
