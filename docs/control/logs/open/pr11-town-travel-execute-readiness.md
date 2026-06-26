# PR #11 Town Travel Execute — Merge Readiness Packet

**Author:** Agent A — Cert / Evidence / Git / PR  
**PR:** [#11](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/11) — **MERGED** @ `09f039f` (2026-06-24)  
**Branch:** `feat/town-to-town-execute-path` — **merged**; safe to delete after user confirms  
**Packet SHA:** `10fc74f` (evidence on merge branch) · **Product baseline:** **`main`** @ `09f039f`  
**Verdict:** **MERGED** — travel execute product evidence sufficient; attach-only execute follow-up remains **optional**.

---

## Evidence index

| Item | Location |
|------|----------|
| **Primary checkpoint** | [`docs/evidence/live-cert/20260624-032408/checkpoint-01-assistive-travel-execute/`](../../evidence/live-cert/20260624-032408/checkpoint-01-assistive-travel-execute/) |
| Manifest | [`manifest.json`](../../evidence/live-cert/20260624-032408/checkpoint-01-assistive-travel-execute/manifest.json) |
| Execute proof | [`BlacksmithGuild_AssistiveTravelExecution.json`](../../evidence/live-cert/20260624-032408/checkpoint-01-assistive-travel-execute/BlacksmithGuild_AssistiveTravelExecution.json) |
| Advisory probe | [`BlacksmithGuild_TownToTownTradeProbe.json`](../../evidence/live-cert/20260624-032408/checkpoint-01-assistive-travel-execute/BlacksmithGuild_TownToTownTradeProbe.json) |
| Phase1 tail | [`Phase1.tail.txt`](../../evidence/live-cert/20260624-032408/checkpoint-01-assistive-travel-execute/Phase1.tail.txt) |
| Runner transcript | [`cert-run-output.txt`](../../evidence/live-cert/20260624-032408/checkpoint-01-assistive-travel-execute/cert-run-output.txt) |
| Cycle metadata | [`cycle-result.json`](../../evidence/live-cert/20260624-032408/checkpoint-01-assistive-travel-execute/cycle-result.json) |

**Evidence commits:** `b577ac2` (checkpoint), `10fc74f` (Status.json force-add)

---

## What was proven

Live session `20260624-032408` — Quyaz → Ortysia via `AssistiveLeaveTownAndTravel` with `execute=true`:

| Claim | Evidence |
|-------|----------|
| `AssistiveLeaveTownAndTravel` accepts `execute=true` | Inbox payload + execution JSON `executeRequested=true` |
| Real travel execute occurred | `travelCommandMode=execute`, Phase1 `[TBG ASSIST] travel stage=map_travel` |
| `certSummary.passCandidate=true` | Execution JSON `certSummary` block |
| `executeAllowed=true` | Execution JSON |
| `travelApiCallSucceeded=true` | Execution JSON |
| `movementObservationPassed=true` | 1ms / 1 attempt observation window |
| `actualExecutionObserved=true` | `routeTargetId=town_EW4 routeMatches=true` |
| `fakeGameplayDelta=false` | Execution JSON + manifest |
| Leave town from settlement menu | `leaveTownAttempted=true`, `leaveTownSucceeded=true`, step `LeaveTown` Success |
| Probe advisory-only (no travel side effects) | Prior probe ack Success; probe JSON `travelCommandMode=advisory_only` |

**Runtime head at cert time:** `67994e9` (Agent B certSummary hardening; DLL deployed with `-SkipBuild` on runner branch).

---

## What was not proven

| Gap | Impact |
|-----|--------|
| **Attach-only** (`launchUsed=false`) | Cert used Agent C launch-assisted path (`launchPath=continue`) |
| **Execute inbox ack** | Timed out after 120s; travel execution JSON still PASS |
| **Agent C runner on PR #11** | Runner lives on `fix/pr11-unattended-execute-cert-runner` — termination provenance separate |
| **Trade execute** | Out of scope — travel execute only; probe remains `advisory_only` |
| **Multiple settlements / edge targets** | Single route proven: Quyaz → Ortysia |

Attach-only follow-up is **recommended but not mandatory** if the user accepts the launch-assisted cert. Do not let missing attach-only evidence block all progress unless the user explicitly requires it.

---

## Risk table

| Risk | Severity | Mitigation |
|------|----------|------------|
| Launch-assisted cert vs attach doctrine | Medium | Optional attach-only follow-up; manifest documents `launchUsed=true` |
| Execute inbox ack timeout | Low | Execution JSON + Phase1 prove command ran; probe ack succeeded |
| Runner branch not merged | Low | Product code on PR #11; runner is harness-only on separate branch |
| Movement observation window (500ms) | Low | Passed in 1ms on live run; Agent B owns extension if tick-delay fails elsewhere |
| Stale inbox sequence regression | Low | PR #10 offline test on `main`; seq=4 probe / seq=5 execute in 032408 |
| PR #8 bisect bundle | None | HOLD — unrelated; do not merge with #11 |

---

## PASS criteria met

```text
executeRequested=true
executeAllowed=true
travelCommandMode=execute
travelApiCallSucceeded=true
movementIntentSet=true
movementObservationPassed=true
actualExecutionObserved=true
fakeGameplayDelta=false
certSummary.passCandidate=true
certSummary.routeOwner=AgentA
leaveTownAttempted=true (settlement_menu start)
```

Phase1 markers present: `travel stage=map_travel`, `AssistiveLeaveTownAndTravel travel mode=execute`.

---

## Static gates (packet authoring time)

| Gate | Result |
|------|--------|
| `dotnet build Release` | PASS |
| `verify-log-grep-patterns.ps1` | PASS |
| `verify-f7-runner-contract.ps1` | PASS (includes `test-assistive-travel-execute-mode.ps1`) |

Re-run before merge if runtime commits land after this packet.

---

## Merge recommendation

**PR #11 MERGED** to **`main`** @ `09f039f`.

Post-merge stacked work (rebase onto `09f039f` before PR):

| Owner | Branch | Task |
|-------|--------|------|
| **Agent B** | `feat/runtime-gameplay-state-machine` @ `69263a9` | Runtime gameplay state machine |
| **Agent C** | `fix/pr11-unattended-execute-cert-runner` @ `70e5404` | Runner termination provenance |
| **Agent A** | — | Optional attach-only execute cert |
| **Agent D** | — | Atlas sync **DONE** (post-merge) |

---

## Conditions for marking ready

1. User chooses option A (mark ready) after evidence review
2. Static gates PASS on current HEAD
3. No open Agent B blocker on execute path (`nextRouteOnFail=AgentB` on live evidence)
4. PR description references this packet and evidence folder

---

## Conditions for merge

1. User explicitly authorizes merge (option C)
2. GitHub PR mergeable + checks acceptable to user
3. Evidence packet and checkpoint committed on PR branch (done @ `10fc74f`)
4. Optional: attach-only cert committed if user required it first

Use **merge commit** (not squash) if preserving discrete evidence commits matters.

---

## Follow-up work after merge

| Owner | Task | Status |
|-------|------|--------|
| **Agent B** | Runtime state-machine — `feat/runtime-gameplay-state-machine` @ `69263a9` | **NEXT** — rebase onto `09f039f` |
| **Agent C** | Runner provenance — `fix/pr11-unattended-execute-cert-runner` @ `70e5404` | **NEXT** — rebase onto `09f039f` |
| **Agent A** | Optional attach-only execute cert | **NOT RUN** |
| **Agent D** | Post-merge atlas sync | **DONE** |
| **Product** | Trade execute lane (`feat/006c-4*`) | Stale — rebase if revived |

---

## User decision menu (historical)

| Option | Action | Outcome |
|--------|--------|---------|
| **A** | Mark PR #11 ready for review | Superseded |
| **B** | Run attach-only cert first | Still **optional** |
| **C** | Merge PR #11 | **DONE** @ `09f039f` |
| **D** | Hold PR #11 | Superseded |

---

## Related

- Prior assist advisory PASS (attach-only): [`20260624-020821`](../../evidence/live-cert/20260624-020821/checkpoint-01-assistive-town-trade/manifest.json)
- F7 cert index: [`docs/control/indexes/f7-recovery-index.md`](../../control/indexes/f7-recovery-index.md)
- Agent coordination: [`docs/handoff/blacksmithguild-agent-coordination.md`](../../../handoff/blacksmithguild-agent-coordination.md)
