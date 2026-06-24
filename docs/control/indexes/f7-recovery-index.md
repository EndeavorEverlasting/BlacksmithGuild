# F7 recovery index

**Branch:** `fix/f7-gate-stability` @ `d5c7bbf`  
**Gate:** **PIVOT** — old F7 product gate closed; forward = Town-to-Town Trade Assist  
**Authority (living):** [`docs/handoff/f7-agent-coordination.md`](../../handoff/f7-agent-coordination.md)  
**Failure map:** [`f7-failure-atlas.md`](f7-failure-atlas.md) · **Artifact matrix:** [`f7-evidence-matrix.md`](f7-evidence-matrix.md)  
**Forward cert:** [`town-to-town-trade-assist-cert.md`](../logs/open/town-to-town-trade-assist-cert.md)  
**Policy:** Index-only — handoff and evidence paths are **not moved**.

---

## PR status

| PR | Branch | Base | State | Posture |
|----|--------|------|-------|---------|
| [#7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7) | `fix/f7-gate-stability` | `main` | OPEN | HOLD — old F7 PASS not sprint medal |
| [#8](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/8) | `codex/stabilize-f7-launch-tooling-and-open-pr` | `fix/f7-gate-stability` | OPEN | HOLD — stub runner rejected |

---

## Classification rules

| Bucket | Criteria |
|--------|----------|
| **successful** | Repo proves complete, certified, merged, closed, or `passFail: PASS` manifest / PASS ledger |
| **open** | Blocked, failed, partial, in progress, pending cert, pending merge, uncertain, or not proven |
| **default** | Ambiguous → open. Not proven → open. **No manifest, no medal.** |

---

## Open plans

| Control pointer | Canonical handoff | Owner | Blocker |
|-----------------|-------------------|-------|---------|
| [town-to-town-trade-assist-cert.md](../logs/open/town-to-town-trade-assist-cert.md) | (this spec) | A/B/C | B probe + inbox poll |
| [f7-recovery-sprint.md](../plans/open/f7-recovery-sprint.md) | [f7-recovery-sprint-handoff.md](../../handoff/f7-recovery-sprint-handoff.md) | A/B/C | **Old F7 closed** — infra only |
| [pr8-runner-salvage.md](../plans/open/pr8-runner-salvage.md) | [pr8-cherry-pick-bridge.md](../../handoff/pr8-cherry-pick-bridge.md) | A/C | PR #8 HOLD |
| [agent-launch-playbook.md](../plans/open/agent-launch-playbook.md) | [agent-launch-and-load-playbook.md](../../handoff/agent-launch-and-load-playbook.md) | B/C | Assist cert pending |

### Open work items

| Item | Status | Evidence |
|------|--------|----------|
| Old F7 Continue product gate | **CLOSED** | `205925` informative FAIL |
| F7 infra (45s launcher, 15s semantic fail) | **DONE** @ `9bdc759` | Agent C |
| Runtime settlement_menu surface | **DONE** @ `e891b33` | Agent B |
| `canPollFileInbox` @ settlement_menu | **OPEN** | **B** |
| `AssistiveTownToTownProbe` | **OPEN** | **B** |
| Town-to-Town assist live cert | **BLOCKED** | **A** after B+C |
| Docs pivot | **DONE** | Agent D |

---

## Successful plans (F7 lane)

**None.** Zero `passFail: PASS` manifests in `docs/evidence/live-cert/`.

---

## Open logs

| Control pointer | Session | passFail | Notes |
|-----------------|---------|----------|-------|
| [session-20260623-205925.md](../logs/open/session-20260623-205925.md) | `205925` | FAIL | **old F7 CLOSED**; settlement_menu |
| [session-20260622-135217.md](../logs/open/session-20260622-135217.md) | `135217` | FAIL | instrumentation_insufficient |
| [session-20260622-131237.md](../logs/open/session-20260622-131237.md) | `131237` | FAIL | contaminated |
| [session-20260622-101016.md](../logs/open/session-20260622-101016.md) | `101016` | FAIL | post-map-ready |

See [`f7-failure-atlas.md`](f7-failure-atlas.md) for full session table.

---

## Raw evidence paths (unmoved)

```
docs/evidence/live-cert/20260623-205925/checkpoint-01-f7-gate/manifest.json  ← latest; old F7 closed
docs/evidence/live-cert/20260622-154012/checkpoint-01-f7-gate/manifest.json
docs/evidence/live-cert/20260622-135217/checkpoint-01-f7-gate/manifest.json
```

**PASS manifests:** none.

---

## Next required action

**Parallel:** Agent B — `canPollFileInbox` + `AssistiveTownToTownProbe`. Agent C — attach runner polish.  
**Serial:** Agent A — Town-to-Town assist cert after B+C land.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-town-to-town-trade-assist-cert.ps1
```

Optional infra validation (not product medal):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F -CertTarget continue
```

---

## Directory layout

```
docs/control/
  README.md
  indexes/
    f7-recovery-index.md       ← this file
    f7-evidence-requirements.md
    f7-failure-atlas.md
    f7-evidence-matrix.md
  plans/open|successful/
  logs/open|successful/
    town-to-town-trade-assist-cert.md
    session-20260623-205925.md
```
