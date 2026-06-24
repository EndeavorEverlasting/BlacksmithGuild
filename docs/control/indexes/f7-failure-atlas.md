# F7 failure atlas

**Branch:** **`main`** @ `3384c7d`  
**Gate:** **GREEN (assist)** — product gate satisfied on advisory path; next blocker = execute path  
**Latest F7 infra:** `20260623-205925` — informative FAIL; settlement_menu; **old F7 CLOSED**  
**Latest product PASS:** `20260624-020821` (attach-only) · `20260624-004036` (setup)  
**Forward cert:** [Town-to-Town Trade Assist](../logs/open/town-to-town-trade-assist-cert.md) — advisory **PASS**; execute path **OPEN**  
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
| `020821` | **product PASS (attach-only)** — `mode=assistive_attach`, `launchUsed=false`, `launchPath=existing_session`, advisory probe Success |
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

1. **Assist product gate is GREEN** — `004036` (setup) + `020821` (attach-only, `launchUsed=false`) PASS manifests on advisory path.
2. **Old F7 Continue product gate is closed** @ `205925` — infrastructure smoke only; semantic mismatch vs in-town runtime.
3. **Inbox sequence regression fixed** — `020430`/`020644` honest FAIL → PR #10 merged → `020821` PASS (seq=3 after consumed seq=2).
4. **Current blocker:** **Agent B** — travel/trade **execute** path (`tradeExecution` / `travelCommandMode` still `advisory_only`).
5. **Forward move:** New feature branch from `main`; execute-path cert earns its own PASS manifest.

---

## evidence_gaps

| Gap | Repo proof |
|-----|------------|
| **`BlacksmithGuild_Status.json` gitignored** | `205925` manifest `statusJsonCopied=true`; assist manifests cite fields inline |
| **`020430`/`020644` checkpoints not committed** | Honest FAIL noted in coordination log; regression covered by PR #10 offline test |
| **Execute path not certified** | `tradeExecution=advisory_only` on all PASS manifests |
| No `CrashContext` on assist PASS | `crashContextCopied=false` on attach-only harvest |
| No `CrashContext` on `205925` | `crashContextCopied=false` |
| Windows crash event | `205925` `windowsCrashEventStatus=query_failed` |
| Historical: `095326` evidence not committed | No checkpoint dir |

---

## next_required_evidence

See [`f7-evidence-requirements.md`](f7-evidence-requirements.md) and [`town-to-town-trade-assist-cert.md`](../logs/open/town-to-town-trade-assist-cert.md).

| Requirement | Owner |
|-------------|-------|
| Travel/trade **execute** path with honest PASS/FAIL | **B** |
| Cert evidence commit after execute work | **A** |
| Runner/attach defects only | **C** (return on defect) |

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
020821 ── Town-to-Town assist PASS (attach-only; launchUsed=false)
```

---

## Related

- [`f7-recovery-index.md`](f7-recovery-index.md) — sprint posture, PR status
- [`f7-evidence-matrix.md`](f7-evidence-matrix.md) — per-session artifact completeness
- [`session-20260623-205925.md`](../logs/open/session-20260623-205925.md) — session stub

