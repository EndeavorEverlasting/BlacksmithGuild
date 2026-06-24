# F7 failure atlas

**Branch:** **`main`** @ `09f039f`  
**Gate:** **GREEN (assist + travel execute)** — travel execute PASS @ `032408`; trade still advisory  
**Latest F7 infra:** `20260623-205925` — informative FAIL; **old F7 CLOSED**  
**Latest product PASS:** `20260624-032408` (travel execute) · `020821` (advisory attach) · `004036` (advisory setup)  
**Forward cert:** [Town-to-Town Trade Assist](../logs/open/town-to-town-trade-assist-cert.md) · [PR #11 packet](../logs/open/pr11-town-travel-execute-readiness.md)  
**Authority:** [`f7-agent-coordination.md`](../../handoff/f7-agent-coordination.md)  
**Normative evidence spec:** [`f7-evidence-requirements.md`](f7-evidence-requirements.md)  
**Artifact matrix:** [`f7-evidence-matrix.md`](f7-evidence-matrix.md)  
**Policy:** Index-only — raw evidence and handoff files are **not moved**.

---

## Play / Continue doctrine

The app must tolerate user input:

- User clicks **Play** → runtime proceeds through the Play path (new campaign, character creation, pre-map setup).
- User clicks **Continue** → runtime proceeds through the Continue path (load save, campaign map readiness).
- User input is **valid operation** — not contamination by default.
- For certs: label **who** selected the path (`launchSelectedBy`: `automation` | `user` | `unknown`).
- **certTarget** = intended cert path. F7 gate runner (`run-f7-gate-continue.ps1`) = **`continue`** (infrastructure only post-pivot).
- **targetMismatch** = `true` when observed `launchPath` ≠ `certTarget`. A Continue cert **cannot** receive a Continue PASS from a Play path — that is forgery.

Historical sessions before wave 3 used **inferred** Play/Continue fields. Session `154012`+ have manifest `launchPath`, `launchSelectedBy`, `certTarget`, `targetMismatch`.

---

## Session index

| sessionId | clean / contaminated | HookMask | certTarget | launchPath | launchSelectedBy | targetMismatch | launcher result | last known phase | last Phase1 marker | last Trace marker | CrashContext copied | passFail | exitCode | stableSeconds | campaignReady | canPollFileInbox | owner | evidence path |
|-----------|------------------------|----------|------------|------------|------------------|----------------|-----------------|------------------|-------------------|-------------------|---------------------|----------|----------|---------------|---------------|------------------|-------|---------------|
| `20260624-032408` | **clean** | n/a | `AssistiveLeaveTownAndTravel` | `continue` | automation | n/a | launch-assisted (`launchUsed=true`) | Quyaz → Ortysia travel **execute** | `travel stage=map_travel` | n/a | no | **PASS** | 0 | n/a | **true** | **true** | **A** | [`…/032408/…`](../../evidence/live-cert/20260624-032408/checkpoint-01-assistive-travel-execute/) |
| `20260624-020821` | **clean** | n/a | n/a | `existing_session` | n/a | n/a | **no launch** (`launchUsed=false`) | **settlement_menu** (Quyaz); attach-only | probe ack Success | n/a | no | **PASS** | 0 | n/a | **true** | **true** | **A** | [`…/020821/…`](../../evidence/live-cert/20260624-020821/checkpoint-01-assistive-town-trade/) |
| `20260624-004036` | **clean** | n/a | n/a | setup path | `automation` | n/a | PASS (Continue ~33s) | **settlement_menu** (Quyaz) | probe ack Success | n/a | no | **PASS** | 0 | n/a | **true** | **true** | **A** | [`…/004036/…`](../../evidence/live-cert/20260624-004036/checkpoint-01-assistive-town-trade/) |
| `20260624-020644` | clean | n/a | n/a | attach-only | n/a | n/a | no launch | settlement_menu | `assistive_probe_failed` | n/a | no | FAIL | 2 | n/a | true | true | **C** | honest FAIL — stale inbox seq (regression context) |
| `20260624-020430` | clean | n/a | n/a | attach-only | n/a | n/a | no launch | settlement_menu | `assistive_probe_failed` | n/a | no | FAIL | 2 | n/a | true | true | **C** | honest FAIL — stale inbox seq; fixed by PR #10 |
| `20260623-205925` | **clean** | `0x0F` | `continue` | `continue` | `automation` | no | PASS (`continueClick` ~4s) | **settlement_menu** (Quyaz); runner MapTransition timeout | `MapTransitionGuard op=MapReadyPrecheck` | same seq=93488 | no | FAIL | 2 | 0 | **true** | **true** | **B** + **C** | [`…/205925/…`](../../evidence/live-cert/20260623-205925/checkpoint-01-f7-gate/) |
| `20260622-154012` | **clean** | `0x0F` | `continue` | `continue` | `automation` | no | partial (`continue_escalate`; `game_spawned`; 368s timeout) | **user: Quyaz town loaded**; runner: Refresh storm | `GameSessionState op=Refresh stage=ok` | same (seq=164435) | no | FAIL | 2 | 0 | false | false | **B** + **C** | [`…/154012/…`](../../evidence/live-cert/20260622-154012/checkpoint-01-f7-gate/) |
| `20260622-135217` | **clean** | `0x0F` | `continue` | `continue` (inferred) | `automation` | no | **PASS** (unattended Continue, hwnd background) | StatusFlush | `[TBG MAPREADY] StatusFlush begin` | none | no | FAIL | 2 | 0 | false | false | **B** | [`…/135217/checkpoint-01-f7-gate/`](../../evidence/live-cert/20260622-135217/checkpoint-01-f7-gate/) |
| `20260622-131237` | **contaminated** | `0x0F` | `continue` | `continue` (inferred) | **user** (manual clicks) | no | partial (`continue_escalate`) | MapTransition | `MainMenu -> MapTransition` | none | no | FAIL | 2 | 0 | false | false | **B/C** | [`…/131237/…`](../../evidence/live-cert/20260622-131237/checkpoint-01-f7-gate/) |
| `20260622-101016` | clean | `0x0F` | `continue` | `continue` (inferred) | `automation` | no | PASS (`continueClick.success`) | post-map-ready | manifest `phase1TbgReady: true`; **no Phase1.tail in checkpoint** | none | no | FAIL | 2 | 0 | false | false | **B** | [`…/101016/…`](../../evidence/live-cert/20260622-101016/checkpoint-01-f7-gate/) |
| `20260622-095957` | clean | `0x07` | `continue` | `continue` (inferred) | `automation` | no | timeout (`launcher_spawned`) | MapTransition → claimed map-ready | `MainMenu -> MapTransition` | none | no | FAIL | 2 | 0 | false | false | **B** | [`…/095957/…`](../../evidence/live-cert/20260622-095957/checkpoint-01-f7-gate/) |
| `20260622-095326` | — | — | `continue` | — | — | — | — | handoff: died after TBG READY | **not in repo** | — | — | — | — | — | — | — | **B** | **evidence not committed** |
| `20260622-030915` | clean | `0x0F` | `continue` | `continue` (inferred) | `automation` | no | PASS (`game_spawned`) | MapTransition | `MainMenu -> MapTransition` | none | no | FAIL | 2 | 0 | false | false | **B** | [`…/030915/…`](../../evidence/live-cert/20260622-030915/checkpoint-01-f7-gate/) |

### Verdict tags

| Session | Classification |
|---------|----------------|
| `032408` | **product PASS (travel execute)** — `travelCommandMode=execute`, `certSummaryPassCandidate=true`, `actualExecutionObserved=true`; `launchUsed=true`; execute inbox ack timeout (execution JSON PASS) |
| `020821` | **product PASS (advisory attach-only)** — `mode=assistive_attach`, `launchUsed=false`, advisory probe Success |
| `004036` | **product PASS (setup)** — launcher setup + assist cert; `tradeExecution=advisory_only` |
| `020644` | **honest FAIL (regression)** — `assistive_probe_failed`; stale inbox sequence; fixed before `020821` |
| `020430` | **honest FAIL (regression)** — same class; PR #10 adds offline regression |
| `205925` | **informative FAIL — old F7 CLOSED** — clean Continue; Quyaz settlement_menu; old gate semantics; **not product PASS** |
| `154012` | **honest FAIL** — `evidenceCompleteness=sufficient`; gameplay reached Quyaz (user-observed); Refresh storm; **not PASS** |
| `135217` | **`instrumentation_insufficient`** — dies at coarse `StatusFlush begin` |
| `131237` | **`contaminated_cert`** |
| `101016` | honest FAIL — `fail_game_gone_after_map_ready` |
| `095957` | honest FAIL — post-map-ready death |
| `095326` | referenced in handoff bisect; **no checkpoint dir in repo** |
| `030915` | honest FAIL — MapTransition before orchestrator tick |

---

## Owner routing

| Failure neighborhood | Owner |
|---------------------|-------|
| `canPollFileInbox=false` at settlement_menu; assist probe missing | **B** |
| F7 poll semantic mismatch; launcher timing; classifier | **C** |
| `GameSessionState` Refresh storm (historical `154012`) | **B** |
| Continue / Safe Mode / launcher timeout / harvest gaps | **C** |
| MapTransition death era (historical) | **B** — largely past |
| Evidence packaging / gameplay cert / PR #7 | **A** |
| Doc drift / atlas | **D** |

### Session `205925` routing

| Observation | Owner |
|-------------|-------|
| Launcher + Continue automation clean | **C** validated |
| Game alive in Quyaz settlement_menu | **B** surface telemetry validated |
| `canPollFileInbox=false` blocks assist + old gate | **B** |
| 361s MapTransition poll (pre-`9bdc759`) | **C** — fixed: 15s semantic mismatch |
| Product forward path | **A** — town-to-town assist cert after B |

---

## current_best_diagnosis

1. **Travel execute product gate is GREEN** — `032408` PASS on `main` @ PR #11: Quyaz → Ortysia, `travelCommandMode=execute`, movement observation passed, `fakeGameplayDelta=false`.
2. **Advisory assist remains proven** — `004036` + `020821` (`travelCommandMode=advisory_only` on probe path).
3. **Accepted gap:** launch-assisted cert (`launchUsed=true`); execute inbox ack timed out; execution JSON proved PASS. Attach-only execute cert **not run** — optional.
4. **Trade execute** still **OPEN** — probe/trade remains `advisory_only`.
5. **Forward move:** Agent B state machine @ `69263a9` + Agent C runner provenance @ `70e5404` (rebase onto `09f039f`); optional A attach-only execute follow-up.

---

## evidence_gaps

| Gap | Repo proof |
|-----|------------|
| **Attach-only execute cert** | Not run; `032408` used `launchUsed=true` |
| **Execute inbox ack timeout** | `inboxAckExecute=timeout` on `032408`; execution JSON PASS |
| **Trade execute** | `tradeExecution=advisory_only` on all manifests |
| **Agent C runner branch** | Harness on `fix/pr11-unattended-execute-cert-runner` — not merged to `main` |
| **`BlacksmithGuild_Status.json` gitignored** | Cite manifest fields |
| Historical: `095326` evidence not committed | No checkpoint dir |

---

## next_required_evidence

See [`f7-evidence-requirements.md`](f7-evidence-requirements.md) and [`town-to-town-trade-assist-cert.md`](../logs/open/town-to-town-trade-assist-cert.md).

| Requirement | Owner |
|-------------|-------|
| Runtime gameplay state machine | **B** @ `69263a9` |
| Unattended execute cert runner merge | **C** @ `70e5404` |
| Optional attach-only execute cert | **A** |
| Trade execute product slice | **B** / product |

---

## failure_timeline

```text
030915 ── MapTransition death (pre-orchestrator)
101016 ── post-map-ready death
135217 ── instrumentation_insufficient
154012 ── user Quyaz; Refresh storm; runner FAIL
205925 ── settlement_menu; old F7 CLOSED; pivot to assist cert
004036 ── Town-to-Town assist PASS (setup path)
020430 ── honest FAIL (stale inbox seq)
020644 ── honest FAIL (stale inbox seq)
020821 ── Town-to-Town assist PASS (attach-only; advisory)
032408 ── travel execute PASS (launch-assisted; PR #11 merged)
```

---

## Related

- [`f7-recovery-index.md`](f7-recovery-index.md) — sprint posture, PR status
- [`f7-evidence-matrix.md`](f7-evidence-matrix.md) — per-session artifact completeness
- [`session-20260623-205925.md`](../logs/open/session-20260623-205925.md) — session stub

