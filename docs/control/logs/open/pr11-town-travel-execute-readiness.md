# PR #11 Town Travel Execute — Merge Readiness Packet

**Author:** Agent A — Cert / Evidence / Git / PR  
**PR:** [#11](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/11)  
**Branch:** `feat/town-to-town-execute-path`  
**Packet SHA:** `10fc74f` (evidence commits `b577ac2`, `10fc74f` on top of runtime `67994e9`)  
**Verdict:** **Merge consideration approved after user review** — product execute evidence is sufficient; attach-only follow-up is recommended but not mandatory.

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

**PR #11 has enough product evidence for merge consideration after user review.**

The launch-assisted execute PASS demonstrates the inbox-gated travel execute path works end-to-end with cert-grade JSON (`certSummary`, movement observation, settlement IDs). Offline contract tests cover mode decision and fallback routing.

**Recommend merge when:**

- User has reviewed evidence folder and this packet
- User accepts launch-assisted cert OR attach-only follow-up is completed separately
- No blocking Agent B runtime defects (`certSummary.nextRouteOnFail=AgentB` on fresh run)

**Do not merge automatically.** Agent A does not mark ready or merge without explicit user authorization.

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

| Owner | Task |
|-------|------|
| **Agent B** | Runtime state-machine / gameplay execute hardening (separate branch) |
| **Agent C** | Runner termination provenance on `fix/pr11-unattended-execute-cert-runner` |
| **Agent A** | Optional attach-only cert → second evidence folder |
| **Agent D** | Sync `f7-agent-coordination.md`, cert index, handoff atlas to post-merge HEAD |
| **Product** | Trade execute lane (`feat/006c-4*`) — travel execute unblocks next leg |

---

## User decision menu

| Option | Action |
|--------|--------|
| **A** | Mark PR #11 ready for review |
| **B** | Run attach-only cert first (user opens game at Quyaz) |
| **C** | Merge PR #11 after user authorization |
| **D** | Hold PR #11; wait for Agent C provenance branch |

---

## Related

- Prior assist advisory PASS (attach-only): [`20260624-020821`](../../evidence/live-cert/20260624-020821/checkpoint-01-assistive-town-trade/manifest.json)
- F7 cert index: [`docs/control/indexes/f7-recovery-index.md`](../../control/indexes/f7-recovery-index.md)
- Agent coordination: [`docs/handoff/f7-agent-coordination.md`](../../../handoff/f7-agent-coordination.md)
