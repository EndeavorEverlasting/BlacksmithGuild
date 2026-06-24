# F7 failure atlas

**Branch:** `fix/f7-gate-stability` @ `d5c7bbf`  
**Gate:** **PIVOT** — old F7 product gate closed; no legacy F7 PASS manifest  
**Latest cert:** `20260623-205925` — informative FAIL; settlement_menu; **old F7 CLOSED**  
**Forward cert:** [Town-to-Town Trade Assist](../logs/open/town-to-town-trade-assist-cert.md)  
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
| `20260623-205925` | **clean** | `0x0F` | `continue` | `continue` | `automation` | no | PASS (`continueClick` ~4s) | **settlement_menu** (Quyaz); runner MapTransition timeout | `MapTransitionGuard op=MapReadyPrecheck` | same seq=93488 | no | FAIL | 2 | 0 | **true** | **false** | **B** + **C** | [`…/205925/…`](../../evidence/live-cert/20260623-205925/checkpoint-01-f7-gate/) |
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
| `205925` | **informative FAIL — old F7 CLOSED** — clean Continue; Quyaz settlement_menu; `campaignReady=true`, `canPollFileInbox=false`; MapTransition treadmill (pre-15s fix); ExternalStateTimeline present; **not product PASS** |
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

1. **MapTransition death / seq=8115 era is past** — `205925` reached settlement_menu with game alive; no process death.
2. **Old F7 Continue product gate is closed** @ `205925` — semantic mismatch: golden path expects MapTransition; runtime is in-town with `canPollFileInbox=false`.
3. **Screenshot / user observation ≠ cert PASS** — manifest `passFail=FAIL`, `stableSeconds=0`. **PR #7 HOLD.**
4. **Current blocker:** (a) **B** — enable `canPollFileInbox` + `AssistiveTownToTownProbe` at settlement_menu; (b) **C** — attach runner ready (skeleton exists).
5. **Forward move:** Town-to-Town Trade Assist Cert ([spec](../logs/open/town-to-town-trade-assist-cert.md)); optional A infra validation of C 15s fail (~15s wall, not 361s).

---

## evidence_gaps

| Gap | Repo proof |
|-----|------------|
| **`BlacksmithGuild_Status.json` gitignored** | `205925` manifest `statusJsonCopied=true`; file not in git — cite manifest |
| **User screenshot not in repo** | Quyaz observed; not committed unless user adds |
| **`AssistiveTownToTownProbe` not implemented** | Assist cert blocked |
| No `CrashContext` on `205925` | `crashContextCopied=false` |
| Windows crash event | `205925` `windowsCrashEventStatus=query_failed` |
| Historical: `095326` evidence not committed | No checkpoint dir |

---

## next_required_evidence

See [`f7-evidence-requirements.md`](f7-evidence-requirements.md) and [`town-to-town-trade-assist-cert.md`](../logs/open/town-to-town-trade-assist-cert.md).

| Requirement | Owner |
|-------------|-------|
| `canPollFileInbox=true` @ settlement_menu | **B** |
| `AssistiveTownToTownProbe` + `inGameAssistReady` | **B** |
| Attach runner ready for gameplay cert | **C** |
| Town-to-Town assist cert with honest PASS/FAIL | **A** (after B+C) |

---

## failure_timeline

```text
030915 ── MapTransition death (pre-orchestrator)
101016 ── post-map-ready death
135217 ── instrumentation_insufficient
154012 ── user Quyaz; Refresh storm; runner FAIL
205925 ── settlement_menu; canPollFileInbox=false; old F7 CLOSED; pivot to assist cert
```

---

## Related

- [`f7-recovery-index.md`](f7-recovery-index.md) — sprint posture, PR status
- [`f7-evidence-matrix.md`](f7-evidence-matrix.md) — per-session artifact completeness
- [`session-20260623-205925.md`](../logs/open/session-20260623-205925.md) — session stub
