# F7 failure atlas

**Branch:** `fix/f7-gate-stability` @ `f975312`  
**Gate:** **RED** — no `passFail: PASS` manifest under `docs/evidence/live-cert/`  
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

Historical sessions below use **inferred** `launchPath` / `launchSelectedBy` from Phase1 and manifest notes until Agent C lands manifest fields.

---

## Session index

| sessionId | clean / contaminated | HookMask | certTarget | launchPath | launchSelectedBy | targetMismatch | launcher result | last known phase | last Phase1 marker | last Trace marker | CrashContext copied | passFail | exitCode | stableSeconds | campaignReady | canPollFileInbox | owner | evidence path |
|-----------|------------------------|----------|------------|------------|------------------|----------------|-----------------|------------------|-------------------|-------------------|---------------------|----------|----------|---------------|---------------|------------------|-------|---------------|
| `20260622-135217` | **clean** | `0x0F` | `continue` | `continue` (inferred) | `automation` | no | **PASS** (unattended Continue, hwnd background) | StatusFlush | `[TBG MAPREADY] StatusFlush begin` | none | no | FAIL | 2 | 0 | false | false | **B** | [`…/135217/checkpoint-01-f7-gate/`](../../evidence/live-cert/20260622-135217/checkpoint-01-f7-gate/) |
| `20260622-131237` | **contaminated** | `0x0F` | `continue` | `continue` (inferred) | **user** (manual clicks) | no | partial (`continue_escalate`) | MapTransition | `MainMenu -> MapTransition` | none | no | FAIL | 2 | 0 | false | false | **B/C** | [`…/131237/…`](../../evidence/live-cert/20260622-131237/checkpoint-01-f7-gate/) |
| `20260622-101016` | clean | `0x0F` | `continue` | `continue` (inferred) | `automation` | no | PASS (`continueClick.success`) | post-map-ready | manifest `phase1TbgReady: true`; **no Phase1.tail in checkpoint** | none | no | FAIL | 2 | 0 | false | false | **B** | [`…/101016/…`](../../evidence/live-cert/20260622-101016/checkpoint-01-f7-gate/) |
| `20260622-095957` | clean | `0x07` | `continue` | `continue` (inferred) | `automation` | no | timeout (`launcher_spawned`) | MapTransition → claimed map-ready | `MainMenu -> MapTransition` | none | no | FAIL | 2 | 0 | false | false | **B** | [`…/095957/…`](../../evidence/live-cert/20260622-095957/checkpoint-01-f7-gate/) |
| `20260622-095326` | — | — | `continue` | — | — | — | — | handoff: died after TBG READY | **not in repo** | — | — | — | — | — | — | — | **B** | **evidence not committed** |
| `20260622-030915` | clean | `0x0F` | `continue` | `continue` (inferred) | `automation` | no | PASS (`game_spawned`) | MapTransition | `MainMenu -> MapTransition` | none | no | FAIL | 2 | 0 | false | false | **B** | [`…/030915/…`](../../evidence/live-cert/20260622-030915/checkpoint-01-f7-gate/) |

### Verdict tags

| Session | Classification |
|---------|----------------|
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
| Continue / Safe Mode / launcher timeout / obscured / harvest gaps | **C** |
| MapTransition before `[TBG MAPREADY]` orchestrator | **B** |
| StatusFlush begin / post-map-ready native death / trace gaps | **B** |
| Evidence packaging / manifest review / PR #7 merge | **A** |

---

## current_best_diagnosis

1. **Launcher passed** on latest **clean Continue** cert `20260622-135217` (`clean_cert`, hwnd SendMessage-background, no manual user clicks).
2. **launchPath** matches **certTarget** (`continue`) — no `targetMismatch` on clean cert.
3. Runtime reaches orchestrator → immediate hooks → **`[TBG MAPREADY] StatusFlush begin`** then native process death.
4. Evidence identifies the **neighborhood** (StatusFlush), not the **exact failing operation** — classify as **`instrumentation_insufficient`**.
5. **Next move:** Agent **B** (RuntimeTrace + StatusFlush sub-steps + `BlacksmithGuild_CrashContext.json` + `path=` on traces) and Agent **C** (larger tails, manifest enrichment, Windows event harvest). Agent **A** wave-2 F7 cert **blocked** until B+C on `origin`.

---

## evidence_gaps

| Gap | Repo proof |
|-----|------------|
| No stack trace in any committed checkpoint | No crash dump or managed stack in evidence dirs |
| No Windows crash event captured | No `WindowsCrashEvents.json` in any session |
| No `BlacksmithGuild_CrashContext.json` | Missing in all listed checkpoints |
| No method-level StatusFlush markers | `135217` Phase1 ends at `StatusFlush begin`; no `[TBG TRACE]` |
| `launchPath` / `launchSelectedBy` / `certTarget` / `targetMismatch` not in manifests | Inferred from Phase1/manifest notes only |
| Phase1 tail too short on `135217` | **24 lines** (target ≥200 per evidence requirements) |
| `101016` missing Phase1.tail in checkpoint | Dir has manifest + Launch.tail + Status.json only |
| Golden path compare missing on `135217` run | manifest `goldenPathCheck.reason`: compare script not present at session end |
| `095326` evidence not committed | No `docs/evidence/live-cert/20260622-095326/` directory |

---

## next_required_evidence

See [`f7-evidence-requirements.md`](f7-evidence-requirements.md). After B+C land:

| Requirement | Owner |
|-------------|-------|
| `[TBG TRACE]` markers with `path=play\|continue\|unknown` | B |
| `BlacksmithGuild_CrashContext.json` (`lastBegin`, `lastSuccess`, `inferredLaunchPath`) | B writes · C copies |
| StatusFlush sub-step `begin` / `ok` / `fail` | B |
| Phase1 tail ≥200–300 lines on FAIL | C |
| Windows crash event query → manifest `windowsCrashEventStatus` | C |
| Manifest: `launchPath`, `launchSelectedBy`, `certTarget`, `targetMismatch`, `lastTraceMarker`, `evidenceCompleteness` | C |

---

## failure_timeline

```text
030915 ── MapTransition death (pre-orchestrator)
101016 ── post-map-ready death (phase1TbgReady true)
095957 ── bisect mask 0x07; MapTransition / claimed map-ready
131237 ── contaminated launcher; MapTransition; no MAPREADY tick
135217 ── clean Continue launcher PASS → StatusFlush begin → instrumentation_insufficient
```

---

## Related

- [`f7-recovery-index.md`](f7-recovery-index.md) — sprint posture, PR status
- [`f7-evidence-matrix.md`](f7-evidence-matrix.md) — per-session artifact completeness
