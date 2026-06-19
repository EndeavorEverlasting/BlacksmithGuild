# Next Steps

Build the car, not the fuzzy dice. Protagonist shaping before economics polish.

---

## Sprint sequencing

| Order | Sprint | Status |
|-------|--------|--------|
| 003C | QuickStart + dev save auto-load + Forge launcher | **LIVE CERT PASS** (Continue, 2026-06-18) |
| 005D | Real candidate mapping + economics | **Hotfix shipped** — live cert optional/pending |
| **006A** | Auto Protagonist Build (`ForgeQuartermasterWarlord`) | **Shipped** — live cert pending |
| **005E** | Orders, inventory, doctrine tuning on real set | **After 006A PASS** |

Prior sprints 004A–005C: **Shipped** (004B live cert PASS 2026-06-18).

---

## Repo state

| Field | Value |
|-------|-------|
| Branch | `main` (006A commit pending push) |
| Version | `v0.0.7` |
| Working tree | Source changes staged for commit |
| Remote | `origin/main` |
| Open PRs | None |
| Stale branches | None |

---

## Next actions (user — 006A live cert)

```text
Close Bannerlord → Forge.cmd → Continue → TBG READY
.\forge.ps1 -Command ApplyAutoCharacterBuild -Wait
.\forge.ps1 -Command ShowForgeStatus -Wait
→ F7: Auto Character Build section + JSON on disk
```

Optional: new SandBox bootstrap (no dev save) → verify auto `TBG CHARACTER:` on map ready.

Docs: [sprint-006a-live-results.md](docs/sprint-006a-live-results.md)

---

## Next actions (dev — after 006A live cert PASS)

**Sprint 005E:** crafting orders + hero inventory in economics; doctrine tuning on real candidates.

**Backlog:** F10 safety guards, player forge UI (006), 005D live cert if still pending.

---

## Stern verdict

Protagonist build is dev/disposable only. Auto-apply fires on **new-game bootstrap** only — Continue requires explicit `ApplyAutoCharacterBuild`.
