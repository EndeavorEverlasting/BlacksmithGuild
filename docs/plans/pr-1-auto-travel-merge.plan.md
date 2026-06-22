# PR #1 — Auto-Travel Merge Plan

**PR:** https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/1  
**Branch:** `codex/add-auto-travel-feature-with-route-avoidance`  
**Base at fork time:** `1cddb09` (66 commits behind current `main`)  
**Status:** OPEN — not mergeable without rebase + P1 API fix + local build/smoke

---

## Push status (2026-06-22)

`origin/main` is synced with local `main` at `8df9c84`. All 66 local commits are on GitHub.

---

## PR summary

| Field | Value |
|-------|-------|
| Title | Add cautious auto-travel commands |
| Commit | `dadc70e` (1 commit on branch) |
| Files | 5 (+375 / -4 lines) |
| New core | `src/BlacksmithGuild/DevTools/AutoTravelService.cs` (285 lines) |
| Docs | `docs/sprint-007-auto-travel.md` |
| Hooks | `BlacksmithGuildCampaignBehavior.OnCampaignTick` → `AutoTravelService.OnCampaignTick()` |

### Commands added

- `ShowAutoTravelChoices`
- `AutoTravelChoice1` … `AutoTravelChoice5`
- `AutoTravelToRecommended`
- `AutoTravel:<town-or-village-name>` (dynamic prefix, not in registry HashSet)

### Behavior

- Ranks 5 nearest towns/villages (town bonus + distance penalty; flat forge bonus if rankings exist)
- Issues map move via reflection; monitors route each campaign tick
- Blocks departure / pauses travel if war-hostile within 6f and strength ≥ player
- Classified as **mutation** + **RequiresRiskyGate** in `DevCommandBus` (Tier 2–3 territory)

---

## Blockers (must fix before merge)

### P1 — Movement API wrong (Codex review)

PR reflects on `MobileParty` for `SetMoveGoToSettlement(Settlement)`.

On Bannerlord **v1.4.6** target, movement order is on **`MobileParty.Ai`**:

```csharp
// Expected pattern (verify against installed TaleWorlds.CampaignSystem.dll):
party.Ai.SetMoveGoToSettlement(destination, ...);
```

Current code looks for non-existent `AiSetMoveGoToSettlement` on `MobileParty` → **all travel commands likely fail** with:
`Bannerlord move-to-settlement API was unavailable`

**Action:** Inspect `MobileParty` / `MobilePartyAi` in game DLLs; implement `party.Ai` path first; keep reflection fallbacks with try/catch.

### P1 — Rebase 66 commits

Branch forked at `1cddb09`. Current `main` has:

- 005E-1 HorseMarket (`HorseMarketRecommendationService`, `AnalyzeHorseMarket`)
- Play-now ack fix (`Send-ForgeCommand` command-name match)
- 008C visible assistive / focus fix
- `DevCommandRegistry` / `DevCommandBus` expanded significantly

**Expect conflicts in:** `DevCommandRegistry.cs`, `DevCommandBus.cs`, possibly `BlacksmithGuildCampaignBehavior.cs`.

---

## Review findings (prioritized)

| Sev | Issue | File | Fix |
|-----|-------|------|-----|
| **P1** | Wrong movement reflection target | AutoTravelService.cs | Use `party.Ai.SetMoveGoToSettlement` |
| **High** | `Method.Invoke` uncaught → session crash | AutoTravelService.cs | try/catch TargetInvocationException |
| **Med** | Clears `_activeDestination` even if hold fails | OnCampaignTick | Only clear after successful hold; retry hold |
| **Med** | `Contains("")` matches all settlements | FindSettlement | Reject empty normalized; remove Contains fallback or log fuzzy match |
| **Med** | Substring fuzzy match surprises | FindSettlement | Exact name/stringId only for v1 |
| **Low** | `forgeBonus` constant — no ranking effect | ScoreSettlement | Tie to top forge town or market intel nearest |
| **Low** | "bandits" message but only `IsAtWarWith` | StartTravel notice | Align copy with war-hostile check |
| **Perf** | `MobileParty.All` every tick | TryDetectBlockingHostiles | Spatial pre-filter or throttle every N ticks |

---

## Missing wiring (vs current main conventions)

PR branch does NOT include:

- [ ] `scripts/dev-command-names.ps1` — add 7 command names + dynamic `AutoTravel:` note
- [ ] `docs/player-command-guide.md` — travel row + campaign-map prerequisite
- [ ] `scripts/export-tbg-evidence.ps1` — if travel JSON added later
- [ ] `DevTools/CommandSurfaceService.cs` — hotkey (optional) or inbox listing
- [ ] `docs/certification-doctrine.md` — Tier 2 travel mutation cert rubric
- [ ] `docs/functionality-status.md` — update "Party travel" from Future → Shipped (after PASS)
- [ ] Move `docs/sprint-007-auto-travel.md` → `docs/plans/007-auto-travel.plan.md` (repo convention)

---

## Recommended merge workflow (next session)

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
git fetch origin
git checkout -b integrate/pr-1-auto-travel origin/codex/add-auto-travel-feature-with-route-avoidance
git rebase origin/main
# resolve conflicts in DevCommandRegistry.cs, DevCommandBus.cs
```

1. Fix `TryInvokeMoveToSettlement` + `TryInvokeHold` (Ai API + try/catch)
2. Fix FindSettlement empty/fuzzy bugs
3. Reconcile `RequiresRiskyGate` / `IsMutationCommand` with cert doctrine (travel = Tier 2)
4. Wire `dev-command-names.ps1`, player guide, functionality-status
5. `dotnet build -c Release`
6. **Smoke (disposable or Continue save on map):**
   ```powershell
   .\forge.ps1 -Command ShowAutoTravelChoices -Wait
   .\forge.ps1 -Command AutoTravelChoice1 -Wait
   ```
7. Verify Phase1: `[TBG TRAVEL] auto-travel started`
8. Squash-merge to main or merge PR on GitHub after push

---

## Cert tier recommendation

Per user preference (play now, skip low-priority certs):

| Item | Tier | Recommendation |
|------|------|----------------|
| Merge + build | 0 | Required |
| ShowAutoTravelChoices on map | 1 | One smoke when convenient |
| AutoTravelChoice1 actually moves party | **2** | Required before trusting on cared-about save |
| Hostile pause behavior | 2 | Manual observation near enemy party |

**Do not block gameplay on Continue** — travel is additive; user can ignore until smoke PASS.

---

## Alignment with product direction

- [`docs/functionality-status.md`](../functionality-status.md) lists "Party travel / map automation" as **Future — after 005E slice**
- PR implements first slice of that roadmap (read [`docs/checkpoints/play-now-cert-triage.md`](../checkpoints/play-now-cert-triage.md))
- Complements 005E economics (market intel → travel to town) but does **not** replace manual play loop

---

## Evidence paths (post-smoke)

```
<BannerlordRoot>/BlacksmithGuild_Phase1.log     → [TBG TRAVEL] lines
<BannerlordRoot>/BlacksmithGuild_Status.json  → lastCommand, campaignReady
docs/evidence/latest/BlacksmithGuild_Phase1.tail.txt
```

No dedicated travel JSON in PR v1 — Phase1 log is canonical.

---

## Do NOT do in merge PR

- Auto buy/sell at destination
- Army command / companion party orders
- Route optimization with market spreads (005E-2)
- Gauntlet UI panel
