# F7 recovery index

**Branch:** `fix/f7-gate-stability` @ `f975312`  
**Gate:** **RED** — no `passFail: PASS` manifest under `docs/evidence/live-cert/`  
**Authority (living):** [`docs/handoff/f7-agent-coordination.md`](../../handoff/f7-agent-coordination.md)  
**Failure map:** [`f7-failure-atlas.md`](f7-failure-atlas.md) · **Artifact matrix:** [`f7-evidence-matrix.md`](f7-evidence-matrix.md)  
**Evidence gate:** [`f7-evidence-requirements.md`](f7-evidence-requirements.md)  
**Policy:** Index-only — handoff and evidence paths are **not moved**.

---

## PR status

| PR | Branch | Base | State | Posture |
|----|--------|------|-------|---------|
| [#7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7) | `fix/f7-gate-stability` | `main` | OPEN | HOLD merge until F7 PASS manifest |
| [#8](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/8) | `codex/stabilize-f7-launch-tooling-and-open-pr` | `fix/f7-gate-stability` | OPEN | HOLD — stub runner rejected; salvage docs only |

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
| [f7-recovery-sprint.md](../plans/open/f7-recovery-sprint.md) | [f7-recovery-sprint-handoff.md](../../handoff/f7-recovery-sprint-handoff.md) | A/B/C | F7 PASS manifest |
| [pr8-runner-salvage.md](../plans/open/pr8-runner-salvage.md) | [pr8-cherry-pick-bridge.md](../../handoff/pr8-cherry-pick-bridge.md) | A/C | PR #8 HOLD; gate RED |
| [agent-launch-playbook.md](../plans/open/agent-launch-playbook.md) | [agent-launch-and-load-playbook.md](../../handoff/agent-launch-and-load-playbook.md) | B/C | F7 not certified |
| [f7-gate-cert-marathon.md](../plans/open/f7-gate-cert-marathon.md) | [f7-gate-cert-marathon-agent-handoff.md](../../handoff/f7-gate-cert-marathon-agent-handoff.md) | A | Marathon incomplete |
| [map-transition-bisect.md](../plans/open/map-transition-bisect.md) | [continue-map-crash-bisect-agent-handoff.md](../../handoff/continue-map-crash-bisect-agent-handoff.md) | B/A | StatusFlush / MapTransition |
| [golden-path-diff.md](../plans/open/golden-path-diff.md) | [f7-golden-path-diff-agent-handoff.md](../../handoff/f7-golden-path-diff-agent-handoff.md) | A | Wave-2 cert pending |

### Open work items

| Item | Status | Evidence |
|------|--------|----------|
| Launcher hwnd-background | **DONE** game-certified @ `135217` | clean Continue cert |
| Runtime StatusFlush instrumentation | **NEXT** Agent B | `135217` `instrumentation_insufficient` |
| Runner evidence harvest | **NEXT** Agent C | matrix gaps (tails, CrashContext, manifest fields) |
| F7 wave-2 cert | **BLOCKED** Agent A | until B+C on origin |
| Post-map-ready survival | OPEN | `101016` `fail_game_gone_after_map_ready` |

---

## Successful plans (F7 lane)

**None.** Zero `passFail: PASS` manifests in `docs/evidence/live-cert/`.

### Historical successful (indexed, not moved)

| Plan | Location | Proof |
|------|----------|-------|
| 006J launcher closeout | [docs/plans/006j-full-live-cert-closeout.plan.md](../../plans/006j-full-live-cert-closeout.plan.md) | LAUNCHER CERT CLOSED; USER PASS Path A/C (pre-F7 sprint) |

---

## Open logs

| Control pointer | Session | passFail | Notes |
|-----------------|---------|----------|-------|
| [session-20260622-135217.md](../logs/open/session-20260622-135217.md) | `135217` | FAIL | **clean** Continue; `instrumentation_insufficient` |
| [session-20260622-131237.md](../logs/open/session-20260622-131237.md) | `131237` | FAIL | contaminated |
| [session-20260622-101016.md](../logs/open/session-20260622-101016.md) | `101016` | FAIL | post-map-ready |
| [superseded-parallel-sprint-chat.md](../logs/open/superseded-parallel-sprint-chat.md) | archive | n/a | superseded chat |
| [live-cert-marathon.md](../logs/open/live-cert-marathon.md) | marathon | n/a | pre-recovery |

### Other FAIL sessions (atlas only — no control stub)

| Session | Notes | In repo? |
|---------|-------|----------|
| `20260622-095957` | mask `0x07`; MapTransition / claimed map-ready | yes |
| `20260622-030915` | MapTransition before orchestrator | yes |
| `20260622-095326` | handoff: died after TBG READY | **no checkpoint dir** |

See [`f7-failure-atlas.md`](f7-failure-atlas.md) for full session table.

---

## Successful logs (F7 lane)

**None.**

---

## Raw evidence paths (unmoved)

```
docs/evidence/live-cert/20260622-135217/checkpoint-01-f7-gate/manifest.json  ← latest clean FAIL (instrumentation_insufficient)
docs/evidence/live-cert/20260622-131237/checkpoint-01-f7-gate/manifest.json  ← contaminated
docs/evidence/live-cert/20260622-101016/checkpoint-01-f7-gate/manifest.json  ← post-map-ready
docs/evidence/live-cert/20260622-095957/checkpoint-01-f7-gate/manifest.json
docs/evidence/live-cert/20260622-030915/checkpoint-01-f7-gate/manifest.json
```

**PASS manifests:** none (`rg '"passFail":\s*"PASS"' docs/evidence/live-cert` → no matches).

---

## Next required action

**Wave 1 (parallel):** Agent B + Agent C push instrumentation/harvest to `origin`.  
**Wave 2 (serial):** Agent A — preflight + F7 cert only after B+C land.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F
```

Judge: exit 0 without manifest `passFail=PASS` and `stableSeconds>=60` is forgery.

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
```
