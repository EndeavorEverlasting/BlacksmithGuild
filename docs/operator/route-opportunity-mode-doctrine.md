# Route Opportunity Mode Doctrine

## Purpose

Route opportunity behavior controls whether travel should move straight from destination to destination or evaluate villages and nearby settlements for optional opportunities.

Villages can contain useful goods, recruitable people, horses, and pack animals. Those opportunities matter for the long-term travel economy, but they must not destabilize basic travel.

This doctrine makes village recruitment, village horse acquisition, and village goods scanning explicit route-mode behavior.

## Core rule

Travel has modes.

The default mode is direct travel.

Exploration is opt-in.

The automation must not silently convert every route into an exploration sweep.

## Route modes

### `direct`

Default mode.

The party travels from the current origin to the selected destination with minimal deviation.

Allowed behavior:

- continue toward target
- avoid danger
- handle manual intervention
- arrive at destination
- run town utility hierarchy

Not allowed by default:

- detouring to villages
- opportunistic recruitment
- horse shopping in villages
- goods shopping in villages
- exploratory settlement scanning

### `exploring`

Optional mode.

The party may evaluate villages and nearby settlements along or near the route for:

- recruits
- horses and pack animals
- useful goods
- food or emergency provisioning
- route-improving opportunities

Exploring mode still cannot ignore survival, safety, food, gold, capacity, or target commitment.

## Modal decision

Village stops are modal decisions, not automatic behavior.

Before stopping at a village, the route opportunity layer must decide:

- current route mode
- current destination
- route deviation cost
- nearby village opportunity score
- food state
- gold state
- horse and capacity state
- party size and recruitment need
- risk level
- whether the stop would improve or harm the route

The decision must be classified as one of:

- `continue_direct_route`
- `inspect_village_opportunity`
- `stop_for_recruitment`
- `stop_for_horses`
- `stop_for_goods`
- `stop_for_food_emergency`
- `skip_opportunity_low_value`
- `skip_opportunity_route_risk`
- `skip_opportunity_insufficient_gold`
- `skip_opportunity_insufficient_capacity`
- `manual_intervention_required`

## Recruitment engine

The recruitment engine is responsible for village and settlement recruitment opportunities.

It should evaluate:

- available recruits
- recruit tier
- recruit type
- faction or culture
- cost
- party size limit
- wage burden
- tactical value
- long-term upgrade path
- route safety impact
- whether recruitment supports the current strategy

Recruitment should be legal and verified.

It must not invent troops, bypass cost, bypass party limits, or mutate the party outside game mechanics.

Expected recruitment outputs:

- `recruitment_not_needed`
- `recruitment_available`
- `recruitment_recommended`
- `recruitment_blocked_party_full`
- `recruitment_blocked_insufficient_gold`
- `recruitment_executed_and_verified`
- `recruitment_failed`

## Horse acquisition engine

The horse acquisition engine should apply the same modal principle.

Villages often have useful horses or pack animals. The system should be able to evaluate those opportunities in exploring mode without making every direct trip a horse-shopping trip.

It should evaluate:

- available horses
- available pack animals
- price
- carrying capacity benefit
- party speed impact
- herd penalty risk
- gold after purchase
- route utility
- whether horses improve the next trade leg

Expected horse outputs:

- `horses_not_needed`
- `horse_opportunity_available`
- `horse_purchase_recommended`
- `horse_purchase_blocked_insufficient_gold`
- `horse_purchase_blocked_capacity_or_speed_penalty`
- `horse_purchase_executed_and_verified`
- `horse_purchase_failed`

## Village goods engine

Village goods are route opportunities, not the primary town market loop.

The village goods engine should evaluate:

- local goods
- food availability
- trade goods
- price
- weight
- expected destination value
- route deviation cost
- whether buying would harm food, horse, or recruitment priorities

Expected goods outputs:

- `goods_not_needed`
- `goods_opportunity_available`
- `goods_purchase_recommended`
- `goods_purchase_blocked_insufficient_gold`
- `goods_purchase_blocked_capacity`
- `goods_purchase_executed_and_verified`
- `goods_purchase_failed`

## Relationship to town utility

Town utility remains the primary ordered branch sequence:

1. Trade sell
2. Trade buy
3. Food provisioning
4. Horse and capacity check
5. Tavern visit
6. Companion recruitment
7. Smithing stamina refresh
8. Use companion stamina for smithing
9. Smith, refine, and smelt
10. Select next profit route

Route opportunity mode operates during travel between towns.

It does not replace the town utility hierarchy.

## Relationship to travel

Travel still comes first.

The route opportunity layer is only allowed to act after the route is stable enough to support optional decisions.

In `direct` mode, the party should not detour for villages unless an emergency requires it.

In `exploring` mode, the party may stop at villages when the opportunity score justifies the deviation.

## Evidence files

Reserve these evidence surfaces:

- `BlacksmithGuild_RouteOpportunityMode.json`
- `BlacksmithGuild_VillageOpportunityScan.json`
- `BlacksmithGuild_RecruitmentDecision.json`
- `BlacksmithGuild_RecruitmentExecution.json`
- `BlacksmithGuild_HorseOpportunityDecision.json`
- `BlacksmithGuild_HorseOpportunityExecution.json`
- `BlacksmithGuild_VillageGoodsDecision.json`
- `BlacksmithGuild_VillageGoodsExecution.json`

## Required mode fields

`BlacksmithGuild_RouteOpportunityMode.json` should include:

- `mode`
- `requestedBy`
- `reason`
- `origin`
- `destination`
- `allowVillageStops`
- `allowRecruitmentStops`
- `allowHorseStops`
- `allowGoodsStops`
- `updatedAtUtc`

Supported modes:

- `direct`
- `exploring`

Default:

- `direct`

## Required village scan fields

`BlacksmithGuild_VillageOpportunityScan.json` should include:

- `origin`
- `destination`
- `currentRoute`
- `nearbyVillages`
- `villagesAlongRoute`
- `deviationCost`
- `risk`
- `foodState`
- `gold`
- `capacity`
- `recruitmentNeed`
- `horseNeed`
- `goodsOpportunity`
- `recommendedStop`
- `decision`
- `reason`
- `updatedAtUtc`

## Required recruitment fields

`BlacksmithGuild_RecruitmentDecision.json` should include:

- `village`
- `availableRecruits`
- `recommendedRecruits`
- `estimatedCost`
- `partySizeBefore`
- `partyLimit`
- `wageImpact`
- `strategyFit`
- `decision`
- `reason`
- `departureAllowedAfter`
- `updatedAtUtc`

`BlacksmithGuild_RecruitmentExecution.json` should include:

- `village`
- `attempted`
- `success`
- `recruitsBefore`
- `recruitsAfter`
- `goldBefore`
- `goldAfter`
- `partySizeBefore`
- `partySizeAfter`
- `itemsOrTroopsAcquired`
- `failureClass`
- `updatedAtUtc`

## Required horse fields

`BlacksmithGuild_HorseOpportunityDecision.json` should include:

- `village`
- `availableHorses`
- `availablePackAnimals`
- `recommendedPurchases`
- `estimatedCost`
- `capacityBenefit`
- `speedImpact`
- `herdPenaltyRisk`
- `goldReserveAfterPurchase`
- `decision`
- `reason`
- `updatedAtUtc`

`BlacksmithGuild_HorseOpportunityExecution.json` should include:

- `village`
- `attempted`
- `success`
- `goldBefore`
- `goldAfter`
- `horsesBefore`
- `horsesAfter`
- `packAnimalsBefore`
- `packAnimalsAfter`
- `itemsBought`
- `failureClass`
- `updatedAtUtc`

## Future CMD surface

This doctrine should support a future shared route-mode CMD surface:

```text
ForgeRouteMode.cmd status
ForgeRouteMode.cmd direct
ForgeRouteMode.cmd exploring
ForgeRouteMode.cmd toggle
```

The route mode should be shared state, not a per-script hidden default.

Expected shared state file:

```text
BlacksmithGuild_RouteOpportunityMode.json
```

Resolution priority should be:

1. explicit command-line route mode
2. shared route opportunity mode JSON
3. safe fallback to `direct`

## Priority

This is a real requirement, but low priority.

It should not block:

- direct travel proof
- manual intervention resume
- arrival detection
- town utility ordering
- food provisioning action path

It should be codified now so later agents do not forget villages, recruitment, horses, and goods exist.

## Implementation boundary

Do not implement village opportunity behavior as always-on.

Do not make villages interrupt direct travel by default.

Do not recruit troops without paying real cost.

Do not buy horses or goods without verifying gold and inventory changes.

Do not treat exploring mode as a substitute for reliable travel.

## Product principle

Villages are optional route opportunities.

Direct travel should stay direct.

Exploration should be explicit, modal, and evidence-backed.
