# Sprint 008C-Fix — Visible Assistive Character Creation

**Status:** CODE SHIPPED — USER visible cert PENDING  
**Parent:** [008c-character-choice-catalog-build-variant-runner.plan.md](008c-character-choice-catalog-build-variant-runner.plan.md)

---

## Problem

Headless 008C catalog runs (`visibleMode: false`, 12 steps/tick) can produce legitimate menu-derived builds but fail the **Visible Assistive Doctrine**: the user cannot watch choices being made. Stale `BlacksmithGuild_CharacterBuildVariantConfig.json` from catalog/matrix poisons subsequent `Forge.cmd` launches.

---

## Visible Assistive Doctrine

| Mode | Audience | `visibleMode` | Steps/tick | Saves |
|------|----------|---------------|------------|-------|
| **AgentHeadless** | Catalog + matrix | `false` | 12 | `BSG_ASR_TEST_*` only |
| **UserVisible** | Personal baseline | `true` | 1 + 750ms | `TBGPersonalAserai001` |
| **Replay** | Best-route visible replay | `true` | 1 + 750ms | cert only |
| **Continue** | Daily play | n/a | n/a | loads existing save |

**TBGPersonalAserai001 from AgentHeadless is UNCERTIFIED** until UserVisible cert passes.

---

## Shipped fixes

1. `scripts/write-character-build-launch-config.ps1` — AgentHeadless / UserVisible / Replay
2. `forge.ps1 -Launch -LaunchIntent play` → UserVisible config before install/launch
3. Catalog/matrix → explicit AgentHeadless + banner
4. `InGameNotice` per culture/upbringing choice when visible
5. Provenance: `visibleTraversalUsed`, `traversalMode`
6. Session-scoped Phase1 mutation audit (no stale `LastApplied` false positives)
7. `RunCharacterBuildVisibleCert.cmd` + `assert-character-legitimacy.ps1`
8. `forge-stop.ps1` excludes caller `$PID` — orchestrators no longer suicide at step [1/5]

---

## USER PASS gate

Run `RunCharacterBuildVisibleCert.cmd`, then analyze:

```
<BannerlordRoot>/
  BlacksmithGuild_CharacterBuildVariantConfig.json   (visibleMode: true)
  BlacksmithGuild_CharacterBuildProvenance.json       (visibleTraversalUsed: true)
  BlacksmithGuild_CharacterVisibleReplay.json         (completed: true)
  BlacksmithGuild_Phase1.log                          (visible traversal: on)

docs/evidence/latest/README.md
docs/evidence/latest/BlacksmithGuild_Phase1.tail.txt
```

---

## Known gaps

- Live catalog/matrix runs still PENDING (agent headless)
- Best-route Replay cert blocked until `CharacterBuildBest.json` exists
- Existing `TBGPersonalAserai001` on disk is disposable/uncertified if created headless
- USER must manually save after cert PASS (script does not auto-save)
- **USER visible cert PENDING** — re-run `RunCharacterBuildVisibleCert.cmd` after forge-stop fix
