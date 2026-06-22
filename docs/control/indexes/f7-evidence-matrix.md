# F7 evidence matrix

**Branch:** `fix/f7-gate-stability` @ `f6c3e68`  
**Normative spec:** [`f7-evidence-requirements.md`](f7-evidence-requirements.md)  
**Failure map:** [`f7-failure-atlas.md`](f7-failure-atlas.md)  
**Policy:** Catalogs **committed** checkpoint artifacts only. Does not edit raw evidence.

**Legend:** `yes` · `no` · `partial` · `inferred` · `n/a`

---

## Artifact completeness by session

| Artifact / field | `154012` | `135217` | `131237` | `101016` | `095957` | `030915` | `095326` |
|------------------|----------|----------|----------|----------|----------|----------|----------|
| `manifest.json` | yes | yes | yes | yes | yes | yes | **not_in_repo** |
| `Launch.tail.txt` | yes (34k) | yes (30k) | yes (35k) | yes (5k) | yes (12k) | yes (23k) | n/a |
| `Phase1.tail.txt` | yes **300 lines** | partial **24** | yes **20** | **no** | yes **20** | yes **20** | n/a |
| Phase1 ≥200 lines | **yes** | no | no | no | no | no | n/a |
| `BlacksmithGuild_Status.json` | yes (435b) | **no** | yes | yes | yes | yes | n/a |
| `BlacksmithGuild_CrashContext.json` | **no** | **no** | **no** | **no** | **no** | **no** | n/a |
| `WindowsCrashEvents.json` | **no** | **no** | **no** | **no** | **no** | **no** | n/a |
| `[TBG TRACE]` in Phase1 tail | **yes** (Refresh storm) | **no** | **no** | **no** | **no** | **no** | n/a |
| `hookMask` in manifest | yes `0x0F` | yes `0x0F` | yes `0x0F` | yes `0x0F` | yes `0x07` | yes `0x0F` | n/a |
| `runnerCommandLine` in manifest | **yes** | **no** | **no** | **no** | **no** | **no** | n/a |
| `evidenceCompleteness` in manifest | **yes** `sufficient` | **no** | **no** | **no** | **no** | **no** | n/a |
| `lastTraceMarker` in manifest | **yes** | **no** | **no** | **no** | **no** | **no** | n/a |
| `launchPath` / `launchSelectedBy` / `certTarget` / `targetMismatch` | **yes** | inferred | inferred | inferred | inferred | inferred | n/a |
| `windowsCrashEventStatus` | `query_failed` | **no** | **no** | **no** | **no** | **no** | n/a |
| `gameProcessRunning` at harvest | **false** (user contradicts) | false | false | false | false | false | n/a |
| User screenshot in repo | **no** | no | no | no | no | no | n/a |

---

## Play / Continue evidence

| Field | `154012` | `135217` | `131237` | `101016` | `095957` | `030915` | `095326` |
|-------|----------|----------|----------|----------|----------|----------|----------|
| `certTarget` | `continue` | `continue` | `continue` | `continue` | `continue` | `continue` | `continue` |
| `launchPath` | `continue` | inferred `continue` | inferred `continue` | inferred `continue` | inferred `continue` | inferred `continue` | unknown |
| `launchSelectedBy` | `automation` | `automation` | **user** (contaminated) | `automation` | `automation` | `automation` | unknown |
| `targetMismatch` | **no** | no | no | no | no | no | unknown |
| `continueEscalated` | **yes** (warning: not cert failure cause) | no | yes | no | no | no | n/a |

---

## Completeness score (honest — not PASS)

Counts **yes** out of 16 tracked rows (excludes `095326`).

| Session | Score | Verdict |
|---------|-------|---------|
| `154012` | **12/16** | honest FAIL; harvest **sufficient**; gameplay progress not cert PASS |
| `135217` | **6/16** | `instrumentation_insufficient` |
| `131237` | **7/16** | `contaminated_cert` |
| `101016` | **5/16** | honest FAIL; missing Phase1.tail |
| `095957` | **7/16** | honest FAIL; short Phase1 |
| `030915` | **7/16** | honest FAIL; MapTransition era |
| `095326` | **0/16** | evidence not committed |

---

## instrumentation_insufficient_sessions

| Session | Why |
|---------|-----|
| `20260622-135217` | Coarse `StatusFlush begin` only; no TRACE; Phase1 tail 24 lines |

**Not** `154012` — trace markers present; `evidenceCompleteness=sufficient`. Failure mode is Refresh storm + runner/user state mismatch.

---

## Session `154012` — user vs runner vs manifest

| Source | Says |
|--------|------|
| **User observation** | Game loaded **Quyaz** town; `[The Blacksmith Guild] Mod loaded. The forge is lit.` — major progress |
| **Manifest** | `passFail=FAIL`, `campaignReady=false`, `canPollFileInbox=false`, `gameProcessRunning=false` |
| **Status.json (checkpoint)** | `campaignReady=false`, `mainHeroReady=false`, `setupPhase=MainMenu`, `forge_lit=PASS` |
| **Phase1 tail (harvested)** | Last 300 lines = `GameSessionState Refresh` / `ReadHero` loop |

**Conclusion:** Screenshot/user observation is **not** cert PASS. Runner and Status.json did not promote readiness to match visible gameplay.

---

## Related

- [`f7-failure-atlas.md`](f7-failure-atlas.md) — session table + diagnosis
- [`f7-recovery-index.md`](f7-recovery-index.md) — PR status + next cert action
