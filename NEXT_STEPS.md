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
| 5 | **003** | Treasury Delta Watch (evidence system) | **003B hardened** — F10 retest pending |
| 5b | **003B** | Treasury hardening (defer snapshot, gen, JSON, dev cmd) | **Shipped** |
| 5c | **003C** | Quick Forge Start (dev save + auto sandbox character) | **Shipped** (2026-06-18) |
| 6 | **004A** | Report formatting / readable log surfaces | **Shipped** (2026-06-18) |
| 7 | **004B** | Forge recommendation data model (stub source) | **Shipped** (2026-06-18) — live cert pending |

> **Breadcrumb:** Load **`BlacksmithGuild_DevStart.sav`** for daily dev — [docs/dev-disposable-save.md](docs/dev-disposable-save.md). **F7** = read-only status verdict card.

---

## Repo state (handoff for next chat)

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.7` |
| Sprint 004A | **Shipped** — ReportFormatter + structured F7 / Treasury / cert output |
| Sprint 004B | **Shipped** — stub RankForgeCandidates + recommendations JSON + F7 forge line |
| Sprint 003B | **Shipped** — F10 retest for treasury deltas still pending |
| Dev loop | Close Bannerlord → **`Forge.cmd`** → load **`BlacksmithGuild_DevStart.sav`** → `TBG READY` |
| Live cert doc | [docs/sprint-004-live-results.md](docs/sprint-004-live-results.md) |

**Next: live cert Sprint 004** — `RankForgeCandidates` → F7 → inspect JSON + Phase1.log.

**Then: 003B treasury retest** — F10 3–5 days + `TreasurySnapshotNow` (still gates real recipe work).

### Sprint entry gates (do not skip)

| Sprint | Enter when | Do not start if |
|--------|------------|-----------------|
| **005+** Real recipe browser | 004B live cert PASS + 003B retest PASS | Stub recommendations not proven in-game |

---

## Sprint 004B: Forge Recommendations (**Shipped** 2026-06-18)

**Command:** `.\forge.ps1 -Command RankForgeCandidates -Wait`

**F7:** compact `TBG FORGE:` line after rankings cached.

**Evidence:** [docs/sprint-004-live-results.md](docs/sprint-004-live-results.md)

---

## Sprint 003: Treasury Delta Watch (**003B retest pending**)

**Retest:** F10 fast-forward 3–5 days (F9 alone does not advance calendar). `.\forge.ps1 -Command TreasurySnapshotNow -Wait`.

---

## Cursor prompt (paste next session)

```text
Repo: EndeavorEverlasting/BlacksmithGuild
Module: v0.0.7

Live cert Sprint 004:
  Forge.cmd → load dev save → TBG READY
  .\forge.ps1 -Command RankForgeCandidates -Wait → F7
  Inspect BlacksmithGuild_ForgeRecommendations.json + Phase1.log

Then 003B treasury retest (F10 3-5 days + TreasurySnapshotNow).
```

---

## Stern verdict

**Next action:** Live cert 004B in-game → 003B F10 retest → real recipe source (Sprint 005+).
