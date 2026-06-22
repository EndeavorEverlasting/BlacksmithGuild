# F7 failure atlas

**Branch:** `fix/f7-gate-stability` @ `f6c3e68`  
**Gate:** **RED** — no `passFail: PASS` manifest under `docs/evidence/live-cert/`  
**Latest cert:** `20260622-154012` — FAIL exit 2; **user reached Quyaz** — **not PASS**  
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
- **certTarget** = intended cert path. F7 gate runner (`run-f7-gate-continue.ps1`) = **`continue`**.
- **targetMismatch** = `true` when observed `launchPath` ≠ `certTarget`. A Continue cert **cannot** receive a Continue PASS from a Play path — that is forgery.

Historical sessions before wave 3 used **inferred** Play/Continue fields. Session `154012` has manifest `launchPath`, `launchSelectedBy`, `certTarget`, `targetMismatch`.

---

## Session index

| sessionId | clean / contaminated | HookMask | certTarget | launchPath | launchSelectedBy | targetMismatch | launcher result | last known phase | last Phase1 marker | last Trace marker | CrashContext copied | passFail | exitCode | stableSeconds | campaignReady | canPollFileInbox | owner | evidence path |
|-----------|------------------------|----------|------------|------------|------------------|----------------|-----------------|------------------|-------------------|-------------------|---------------------|----------|----------|---------------|---------------|------------------|-------|---------------|
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
| `154012` | **honest FAIL** — `evidenceCompleteness=sufficient`; B/C harvest worked; **gameplay reached Quyaz (user-observed)** but manifest `campaignReady=false`, `gameProcessRunning=false`; tail flooded with `GameSessionState Refresh` storm; **not PASS** |
| `135217` | **`instrumentation_insufficient`** — dies at coarse `StatusFlush begin`; no sub-ops, no CrashContext |
| `131237` | **`contaminated_cert`** — unattended cert invalid; not Play/Continue mismatch |
| `101016` | honest FAIL — `fail_game_gone_after_map_ready` |
| `095957` | honest FAIL — post-map-ready death (timeout boundary); bisect mask `0x07` |
| `095326` | referenced in handoff bisect; **no checkpoint dir in repo** |
| `030915` | honest FAIL — MapTransition before orchestrator tick |

---

## Owner routing

| Failure neighborhood | Owner |
|---------------------|-------|
| `GameSessionState` Refresh storm; readiness never promotes (`campaignReady` / `mainHeroReady`) | **B** |
| Runner `gameProcessRunning=false` while user sees game alive; `continue_escalate` friction | **C** |
| Continue / Safe Mode / launcher timeout / harvest gaps | **C** |
| MapTransition before orchestrator (historical — likely past) | **B** |
| StatusFlush begin / native death (historical `135217`) | **B** |
| Evidence packaging / manifest review / recert / PR #7 merge | **A** |

### Session `154012` routing

| Observation | Owner |
|-------------|-------|
| Early session passed StatusFlush neighborhood (`AfterFlushWrite`, `MapTransitionGuard defer`, `EvaluateMapReady defer` — per wave 3 cert; not in harvested 300-line tail) | **B** (historical fix landed) |
| Tail ends in Refresh/ReadHero loop; `campaignReady` stays false in Status.json | **B** |
| `continueEscalated=true`; launcher 368s timeout; runner declared game gone | **C** |
| User screenshot: Quyaz + `[The Blacksmith Guild] Mod loaded. The forge is lit.` — **major progress, not cert PASS** | **A** documents; **B/C** fix detection/promotion |

---

## current_best_diagnosis

1. **Old MapTransition crash neighborhood is likely past** — wave 3 session `154012` progressed through early guards (`AfterFlushWrite`, `MapTransitionGuard defer`, `EvaluateMapReady defer`) and **user-observed gameplay in Quyaz** with mod load message.
2. **Screenshot / user observation ≠ cert PASS** — manifest remains `passFail=FAIL`, `exitCode=2`, `stableSeconds=0`, `campaignReady=false`, `canPollFileInbox=false`. **PR #7 HOLD. No manifest, no medal.**
3. **B markers and C harvest both worked** on `154012`: `evidenceCompleteness=sufficient`, `traceMarkersPresent=true`, `phase1TailLineCount=300`, manifest `launchPath`/`launchSelectedBy`/`certTarget`/`targetMismatch` populated, `harvestError` absent.
4. **Current blocker:** (a) **runtime readiness promotion** — Phase1 tail flooded with `GameSessionState op=Refresh` storm; Status.json snapshot shows `campaignReady=false`, `mainHeroReady=false`, `setupPhase=MainMenu` despite user seeing town; (b) **runner process detection false-negative** — manifest `gameProcessRunning=false` contradicts user-observed alive game in Quyaz.
5. **Next move:** Agent **B** — throttle/diagnose Refresh storm and promote readiness honestly; Agent **C** — fix process-alive detection and `continue_escalate` friction; Agent **A** — recert after B+C land.

---

## evidence_gaps

| Gap | Repo proof |
|-----|------------|
| **User screenshot not in repo** | Quyaz load observed by user; not committed as cert artifact unless user/repo adds it |
| **Runner vs user state mismatch** | `154012` manifest `gameProcessRunning=false` while user reports game alive in Quyaz |
| **Status.json vs gameplay** | `154012` checkpoint Status.json: `campaignReady=false`, `mainHeroReady=false`; contradicts user town observation |
| **`BlacksmithGuild_Status.json` gitignored** | Copied into checkpoint @ harvest but may be omitted from git by ignore rules — verify commit policy |
| No `BlacksmithGuild_CrashContext.json` on `154012` | manifest `crashContextCopied=false`, `reason=not_present` |
| Windows crash event | `154012` `windowsCrashEventStatus=query_failed` |
| Harvested Phase1 tail omits early markers | `154012` tail is 300-line **Refresh storm**; early `AfterFlushWrite`/guard defer lines not in committed tail |
| Historical: no stack trace | Pre-`154012` checkpoints |
| Historical: `135217` instrumentation | Coarse `StatusFlush begin` only |
| `095326` evidence not committed | No checkpoint dir |

---

## next_required_evidence

See [`f7-evidence-requirements.md`](f7-evidence-requirements.md).

| Requirement | Owner |
|-------------|-------|
| Fix Refresh storm / promote `campaignReady` + `mainHeroReady` when map/town actually ready | **B** |
| Runner process-alive detection aligned with user-visible game state | **C** |
| Reduce `continue_escalate` false friction on clean certs | **C** |
| Optional: commit user screenshot or link as supplemental (not PASS substitute) | **A** / user |
| Recert with honest PASS/FAIL manifest only | **A** (after B+C) |

---

## failure_timeline

```text
030915 ── MapTransition death (pre-orchestrator)
101016 ── post-map-ready death (phase1TbgReady true)
095957 ── bisect mask 0x07; MapTransition / claimed map-ready
131237 ── contaminated launcher; MapTransition; no MAPREADY tick
135217 ── clean Continue launcher PASS → StatusFlush begin → instrumentation_insufficient
154012 ── wave 3: early guards passed; user Quyaz + forge lit; runner FAIL; Refresh storm; gameProcessRunning=false
```

---

## Related

- [`f7-recovery-index.md`](f7-recovery-index.md) — sprint posture, PR status
- [`f7-evidence-matrix.md`](f7-evidence-matrix.md) — per-session artifact completeness
