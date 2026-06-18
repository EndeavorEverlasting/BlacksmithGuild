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
| 6 | **004+** | Recommendation system | Later |

> **Breadcrumb:** Load **`BlacksmithGuild_DevStart.sav`** for daily dev — [docs/dev-disposable-save.md](docs/dev-disposable-save.md). **F7** = read-only status verdict card.

---

## Repo state (handoff for next chat)

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.6` |
| Sprint 003C | **Shipped** — dev save docs + auto sandbox character (Harmony, dev-only) |
| Sprint 003B | **Shipped** — F10 retest for treasury deltas still pending |
| Dev loop | Close Bannerlord → **`Forge.cmd`** → load **`BlacksmithGuild_DevStart.sav`** → `TBG READY` |
| Quick start doc | [docs/dev-disposable-save.md](docs/dev-disposable-save.md) |

**Next: 003B retest** — F10 3–5 days on dev save, F7, `TreasurySnapshotNow`, inspect JSON.

**Then Sprint 004** — Forge recommendation data model (gated on 003B retest PASS).

### Sprint entry gates (do not skip)

| Sprint | Enter when | Do not start if |
|--------|------------|-----------------|
| **004+** Recommendations | 003 evidence stable + 003B retest PASS | Treasury watch not proven safe |

---

## Sprint 003C: Quick Forge Start (**Shipped** 2026-06-18)

**Phase 1:** [docs/dev-disposable-save.md](docs/dev-disposable-save.md) — load `BlacksmithGuild_DevStart.sav` (~30s to map).

**Phase 2:** `DevToolsConfig.AutoSkipCharacterCreation = true` — Harmony patches `SandBoxGameManager.OnLoadFinished` + `CharacterCreationState.NextStage`; `CampaignSetupStateTracker` logs menu/cutscene/creation transitions.

**Retest Phase 1:** Load dev save → `TBG READY` → F7.

**Retest Phase 2:** New Sandbox → no UI clicks → `[TBG QUICKSTART] transition:` in log → `TBG QUICKSTART` notice → `TBG READY`.

**If Phase 2 fails:** use Phase 1 dev save; optional external QuickStart mod as fallback.

---

## Sprint 003: Treasury Delta Watch (**003B shipped**)

**Retest:** F10 fast-forward 3–5 days (F9 alone does not advance calendar). `.\forge.ps1 -Command TreasurySnapshotNow -Wait`.

---

## Cursor prompt (paste next session)

```text
Repo: EndeavorEverlasting/BlacksmithGuild

Sprint 003C shipped. Daily dev: load BlacksmithGuild_DevStart.sav (see docs/dev-disposable-save.md).

Retest 003B treasury:
  Forge.cmd → load dev save → F10 ON (3-5 days) → F10 OFF → F7
  .\forge.ps1 -Command TreasurySnapshotNow -Wait

Then Sprint 004 recommendation model.
```

---

## Stern verdict

**Next action:** Create dev save if missing → 003B F10 retest → Sprint 004 recommendation model.
