# F7 evidence matrix

**Branch:** `fix/f7-gate-stability` @ `f975312`  
**Normative spec:** [`f7-evidence-requirements.md`](f7-evidence-requirements.md) (Agent A @ `6d83a34`)  
**Failure map:** [`f7-failure-atlas.md`](f7-failure-atlas.md)  
**Policy:** Catalogs **committed** checkpoint artifacts only. Does not edit raw evidence.

**Legend:** `yes` · `no` · `partial` · `inferred` · `n/a`

---

## Artifact completeness by session

| Artifact / field | `135217` | `131237` | `101016` | `095957` | `030915` | `095326` |
|------------------|----------|----------|----------|----------|----------|----------|
| `manifest.json` | yes | yes | yes | yes | yes | **not_in_repo** |
| `Launch.tail.txt` | yes (30k) | yes (35k) | yes (5k) | yes (12k) | yes (23k) | n/a |
| `Phase1.tail.txt` | partial **24 lines** | yes **20 lines** | **no** | yes **20 lines** | yes **20 lines** | n/a |
| Phase1 ≥200 lines | no | no | no | no | no | n/a |
| `BlacksmithGuild_Status.json` | **no** | yes | yes | yes | yes | n/a |
| `BlacksmithGuild_CrashContext.json` | **no** | **no** | **no** | **no** | **no** | n/a |
| `WindowsCrashEvents.json` | **no** | **no** | **no** | **no** | **no** | n/a |
| `[TBG VERSION]` in Phase1 | yes `v0.0.11` | not verified in tail | n/a | not in tail grep | not in tail grep | n/a |
| last Phase1 marker documented | yes | yes | inferred from manifest | yes | yes | handoff only |
| last `[TBG TRACE]` marker | **no** | **no** | **no** | **no** | **no** | n/a |
| `hookMask` in manifest | yes `0x0F` | yes `0x0F` | yes `0x0F` | yes `0x07` | yes `0x0F` | n/a |
| `runnerCommandLine` in manifest | **no** | **no** | **no** | **no** | **no** | n/a |
| `evidenceCompleteness` in manifest | **no** | **no** | **no** | **no** | **no** | n/a |
| `lastTraceMarker` in manifest | **no** | **no** | **no** | **no** | **no** | n/a |
| `goldenPathCheck` run | **no** (script absent at run) | varies | yes | yes | yes | n/a |
| `windowsCrashEventStatus` | **no** | **no** | **no** | **no** | **no** | n/a |

---

## Play / Continue evidence (inferred until post-C manifests)

| Field | `135217` | `131237` | `101016` | `095957` | `030915` | `095326` |
|-------|----------|----------|----------|----------|----------|----------|
| `certTarget` | `continue` | `continue` | `continue` | `continue` | `continue` | `continue` |
| `launchPath` | inferred `continue` | inferred `continue` | inferred `continue` | inferred `continue` | inferred `continue` | unknown |
| `launchSelectedBy` | `automation` | **user** (contaminated) | `automation` | `automation` | `automation` | unknown |
| `targetMismatch` | no | no | no | no | no | unknown |
| Phase1 `launch intent: continue` | yes | yes | not in checkpoint | yes | yes | n/a |

---

## Completeness score (honest — not PASS)

Counts **yes** + **partial** out of 14 tracked rows above (excludes `095326`).

| Session | Score | Verdict |
|---------|-------|---------|
| `135217` | **6/14** | `instrumentation_insufficient` |
| `131237` | **7/14** | `contaminated_cert` |
| `101016` | **5/14** | honest FAIL; missing Phase1.tail |
| `095957` | **7/14** | honest FAIL; short Phase1 |
| `030915` | **7/14** | honest FAIL; MapTransition era |
| `095326` | **0/14** | evidence not committed |

---

## instrumentation_insufficient_sessions

Sessions where FAIL does **not** identify last completed sub-op and next attempted sub-op:

| Session | Why |
|---------|-----|
| `20260622-135217` | Last marker = coarse `StatusFlush begin`; no TRACE; no CrashContext; Phase1 tail 24 lines |

Per [`f7-evidence-requirements.md`](f7-evidence-requirements.md): route **Agent B** + **Agent C** before treating as regression proof. **Do not merge PR #7.**

---

## Useful FAIL identification (target post-B+C)

| Question | Source after sprint |
|----------|---------------------|
| Last completed marker | Last `[TBG TRACE] … stage=ok` or last MAPREADY ok line |
| Next attempted marker | Last `[TBG TRACE] … stage=begin` or `CrashContext.lastBegin` |
| Play vs Continue | `CrashContext.inferredLaunchPath` + manifest `launchPath` |
| Cert path honesty | manifest `targetMismatch` must be `false` for unattended Continue cert |
| Artifact gaps | manifest `evidenceCompleteness` |

---

## Related

- [`f7-failure-atlas.md`](f7-failure-atlas.md) — session table + diagnosis
- [`f7-recovery-index.md`](f7-recovery-index.md) — PR status + next cert action
