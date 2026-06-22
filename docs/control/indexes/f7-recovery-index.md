# F7 recovery index

**Branch:** `fix/f7-gate-stability` @ `3ca823b`  
**Gate:** **RED** — no `passFail: PASS` manifest under `docs/evidence/live-cert/`  
**Authority (living):** [`docs/handoff/f7-agent-coordination.md`](../../handoff/f7-agent-coordination.md)  
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
| [map-transition-bisect.md](../plans/open/map-transition-bisect.md) | [continue-map-crash-bisect-agent-handoff.md](../../handoff/continue-map-crash-bisect-agent-handoff.md) | B/A | `131237` MapTransition |
| [golden-path-diff.md](../plans/open/golden-path-diff.md) | [f7-golden-path-diff-agent-handoff.md](../../handoff/f7-golden-path-diff-agent-handoff.md) | A | Clean cert pending |

### Open work items (not separate plan files)

| Item | Status | Evidence |
|------|--------|----------|
| Launcher hwnd-background clicks | Implemented @ `9b40b96`; **not game-certified** | `131237` still FAIL / contaminated |
| Post-map-ready C# hardening | Implemented @ `5fac5e9`; **not F7-certified** | `101016` `fail_game_gone_after_map_ready` |
| MapTransition crash investigation | OPEN | `131237`, `030915` |

---

## Successful plans (F7 lane)

**None.** Zero `passFail: PASS` manifests in `docs/evidence/live-cert/`.

### Historical successful (indexed, not moved)

| Plan | Location | Proof |
|------|----------|-------|
| 006J launcher closeout | [docs/plans/006j-full-live-cert-closeout.plan.md](../../plans/006j-full-live-cert-closeout.plan.md) | LAUNCHER CERT CLOSED; USER PASS Path A/C (pre-F7 sprint) |

---

## Open logs

| Control pointer | Session / source | passFail | Evidence path |
|-----------------|------------------|----------|---------------|
| [session-20260622-131237.md](../logs/open/session-20260622-131237.md) | `20260622-131237` | FAIL | `docs/evidence/live-cert/20260622-131237/checkpoint-01-f7-gate/` |
| [session-20260622-101016.md](../logs/open/session-20260622-101016.md) | `20260622-101016` | FAIL | `docs/evidence/live-cert/20260622-101016/checkpoint-01-f7-gate/` |
| [superseded-parallel-sprint-chat.md](../logs/open/superseded-parallel-sprint-chat.md) | archived chat | n/a | [f7-parallel-sprint-agent-chat.md](../../handoff/f7-parallel-sprint-agent-chat.md) |
| [live-cert-marathon.md](../logs/open/live-cert-marathon.md) | marathon handoff | n/a | [live-cert-marathon-agent-handoff.md](../../handoff/live-cert-marathon-agent-handoff.md) |

### Other key FAIL sessions (raw evidence only — no control log stub yet)

| Session | launchState / notes | Manifest |
|---------|---------------------|----------|
| `20260622-095326` | Died after TBG READY (~83s), mask `0x01` | `docs/evidence/live-cert/20260622-095326/checkpoint-01-f7-gate/manifest.json` |
| `20260622-030915` | MapTransition before MapReady | `docs/evidence/live-cert/20260622-030915/checkpoint-01-f7-gate/manifest.json` |

---

## Successful logs (F7 lane)

**None.**

---

## Handoff files left in place (13)

All remain under `docs/handoff/` — heavily cross-linked; Agent A coordination lane active.

| File | Why not moved |
|------|---------------|
| `f7-agent-coordination.md` | Living authority + agent board |
| `f7-recovery-sprint-handoff.md` | Stable DoD reference; linked from coordination |
| `agent-launch-and-load-playbook.md` | Launch doctrine; many inbound links |
| `pr8-cherry-pick-bridge.md` | PR #8 salvage policy |
| `f7-gate-cert-marathon-agent-handoff.md` | Marathon context |
| `continue-map-crash-bisect-agent-handoff.md` | Bisect reference |
| `f7-golden-path-diff-agent-handoff.md` | Golden-path analysis |
| `f7-parallel-sprint-agent-chat.md` | Superseded archive |
| `live-cert-marathon-agent-handoff.md` | Pre-recovery triage |
| `006b-map-trade-cohesion-agent-handoff.md` | Prior sprint; out of F7 lane |
| `006c-assistive-guild-loop-agent-handoff.md` | Prior sprint |
| `009a-clan-intel-agent-handoff.md` | Prior sprint |
| `launch-and-doc-index-agent-handoff.md` | Prior sprint |

---

## Raw evidence paths (unmoved)

```
docs/evidence/live-cert/20260622-131237/checkpoint-01-f7-gate/manifest.json  ← latest honest FAIL
docs/evidence/live-cert/20260622-101016/checkpoint-01-f7-gate/manifest.json  ← post-map-ready FAIL
docs/evidence/live-cert/20260622-095326/checkpoint-01-f7-gate/manifest.json
docs/evidence/live-cert/20260622-030915/checkpoint-01-f7-gate/manifest.json
```

**PASS manifests in repo:** none (verified: `rg '"passFail":\s*"PASS"' docs/evidence/live-cert` → no matches).

---

## Next required cert action

1. Static preflight on `fix/f7-gate-stability`:

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
git checkout fix/f7-gate-stability
git pull origin fix/f7-gate-stability
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-f7-runner-contract.ps1
```

2. **Agent A** — stop `ForgeContinue` / release automation lock; run clean F7 cert (game required):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F
```

3. Judge: exit 0 without manifest `passFail=PASS` and `stableSeconds>=60` is forgery.

---

## Directory layout

```
docs/control/
  README.md
  indexes/f7-recovery-index.md    ← this file
  plans/open/                     ← pointer stubs → handoff
  plans/successful/               ← empty (no F7 PASS)
  logs/open/                      ← pointer stubs → evidence / handoff
  logs/successful/                ← empty
```
