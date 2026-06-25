# F7 recovery index

**Branch:** **`main`** @ `09f039f`  
**Gate:** **GREEN (assist + travel execute)** — advisory + launch-assisted travel execute PASS  
**Authority (living):** [`docs/handoff/blacksmithguild-agent-coordination.md`](../../handoff/blacksmithguild-agent-coordination.md)
**Failure map:** [`f7-failure-atlas.md`](f7-failure-atlas.md) · **Artifact matrix:** [`f7-evidence-matrix.md`](f7-evidence-matrix.md)  
**Forward cert:** [`town-to-town-trade-assist-cert.md`](../logs/open/town-to-town-trade-assist-cert.md) · [`pr11-town-travel-execute-readiness.md`](../logs/open/pr11-town-travel-execute-readiness.md)  
**Policy:** Index-only — handoff and evidence paths are **not moved**.

---

## PR status

| PR | Branch | Base | State | Posture |
|----|--------|------|-------|---------|
| [#7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7) | `fix/f7-gate-stability` | `main` | **MERGED** | F7 infra + assist foundation |
| [#10](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/10) | `test/assistive-inbox-sequence-regression` | `main` | **MERGED** | Inbox sequence regression |
| [#11](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/11) | `feat/town-to-town-execute-path` | `main` | **MERGED** | Travel execute path |
| [#8](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/8) | `codex/stabilize-f7-launch-tooling-and-open-pr` | `fix/f7-gate-stability` | OPEN | **HOLD** — stub runner rejected |

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
| [pr11-town-travel-execute-readiness.md](../logs/open/pr11-town-travel-execute-readiness.md) | PR #11 packet | D | **MERGED** — historical reference |
| [town-to-town-trade-assist-cert.md](../logs/open/town-to-town-trade-assist-cert.md) | (this spec) | B/A | Trade execute + state machine |
| [f7-recovery-sprint.md](../plans/open/f7-recovery-sprint.md) | [f7-recovery-sprint-handoff.md](../../handoff/f7-recovery-sprint-handoff.md) | A/B/C | **Old F7 closed** — infra only |
| [pr8-runner-salvage.md](../plans/open/pr8-runner-salvage.md) | [pr8-cherry-pick-bridge.md](../../handoff/pr8-cherry-pick-bridge.md) | A/C | PR #8 HOLD |

### Open work items

| Item | Status | Evidence |
|------|--------|----------|
| Old F7 Continue product gate | **CLOSED** | `205925` informative FAIL |
| Town-to-Town assist (advisory) | **PASS** | `004036` + `020821` |
| Travel execute path (PR #11) | **MERGED** / **PASS** | `032408` @ `09f039f` |
| Inbox sequence regression | **MERGED** @ PR #10 | offline test |
| Attach-only execute cert | **NOT RUN** | optional Agent A follow-up |
| Runtime gameplay state machine | **OPEN** | **Agent B** @ `69263a9` — rebase onto `09f039f` |
| Unattended execute cert runner | **OPEN** | **Agent C** @ `70e5404` — rebase onto `09f039f` |
| Trade execute | **OPEN** | future product slice |
| Docs post-PR #11 atlas | **DONE** | Agent D |

---

## Successful plans (product lane)

| Item | Session | Notes |
|------|---------|-------|
| Travel execute (launch-assisted) | `20260624-032408` | [`manifest`](../../evidence/live-cert/20260624-032408/checkpoint-01-assistive-travel-execute/manifest.json) — `travelCommandMode=execute` |
| Town-to-Town Trade Assist (setup) | `20260624-004036` | advisory probe PASS |
| Town-to-Town Trade Assist (attach-only) | `20260624-020821` | `launchUsed=false` |

---

## Open logs (F7 infra — historical)

| Control pointer | Session | passFail | Notes |
|-----------------|---------|----------|-------|
| [session-20260623-205925.md](../logs/open/session-20260623-205925.md) | `205925` | FAIL | **old F7 CLOSED**; settlement_menu |

See [`f7-failure-atlas.md`](f7-failure-atlas.md) for full session table.

---

## Raw evidence paths (unmoved)

```
docs/evidence/live-cert/20260624-032408/checkpoint-01-assistive-travel-execute/manifest.json  ← travel execute PASS
docs/evidence/live-cert/20260624-020821/checkpoint-01-assistive-town-trade/manifest.json    ← advisory attach PASS
docs/evidence/live-cert/20260624-004036/checkpoint-01-assistive-town-trade/manifest.json    ← advisory setup PASS
docs/evidence/live-cert/20260623-205925/checkpoint-01-f7-gate/manifest.json                  ← closed F7 infra
```

---

## Next required action

**Parallel stacked (rebase onto `main` @ `09f039f` before PR):**

- **Agent B** — `feat/runtime-gameplay-state-machine` @ `69263a9`
- **Agent C** — `fix/pr11-unattended-execute-cert-runner` @ `70e5404`

**Optional:** Agent A attach-only execute cert (`launchUsed=false`).

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
    pr11-town-travel-execute-readiness.md
    session-20260623-205925.md
```
