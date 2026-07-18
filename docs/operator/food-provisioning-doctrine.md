# Food Provisioning Doctrine

## Purpose

Food provisioning is an actionable town branch in the Travel Logistics Circuit.

It is not only a status note, warning, or future idea. When the branch is called and the market can satisfy it, the system must decide what food to buy, execute the legal buy path, verify the result, and record evidence.

Food provisioning runs after trade sell/buy and before horse/capacity checks.

## Position in town hierarchy

The town utility order is:

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

Food comes after the market trade pass because gold, inventory pressure, and cargo space may change during trade.

Food comes before horses and capacity because departure safety must be known before deciding how much route and cargo expansion is useful.

## Core rule

Food provisioning must either buy food and prove the result, or block departure with a useful reason.

If food is below the required route-safe threshold, departure is not allowed unless the food branch has produced one of these classified outcomes:

- `food_target_met`
- `food_bought_and_verified`
- `food_unavailable_in_market`
- `insufficient_gold_for_food`
- `insufficient_capacity_for_food`
- `manual_intervention_required`
- `food_provisioning_blocked_with_reason`

A vague warning is not enough.

## Required advisor behavior

The food provisioning advisor must answer:

- How many party members need feeding?
- How many food units are currently available?
- How many estimated food days are currently covered?
- What route or travel buffer is required before departure?
- What food is available in the current town market?
- What food should be bought?
- How much gold can be spent without breaking route or trade survival?
- Whether cargo capacity allows the purchase.
- Whether the town should block departure until food is solved.

The advisor must output a decision, not just diagnostics.

Expected decision names:

- `hold_food_target_met`
- `buy_food`
- `emergency_buy_food`
- `block_departure_no_food`
- `block_departure_insufficient_gold`
- `block_departure_insufficient_capacity`
- `block_departure_market_unavailable`
- `manual_intervention_required`

## Required buy path

When the decision is `buy_food` or `emergency_buy_food`, the system must:

1. Read current party food state.
2. Read current gold.
3. Read current inventory and capacity state.
4. Read current town market food candidates.
5. Select food candidates using a documented ranking.
6. Buy enough food to reach the target threshold when possible.
7. Pay the real market cost.
8. Verify gold changed.
9. Verify food inventory changed.
10. Recompute food days.
11. Emit final provisioning evidence.
12. Allow or block departure based on the verified result.

The buy path must use real game mechanics. It must not synthesize food, gold, or inventory changes outside legal gameplay mechanics.

## Food selection ranking

Food selection should prefer:

1. Affordable food that helps reach the target days.
2. Better food-days-per-gold value.
3. Lower weight or better food-days-per-weight value when capacity is tight.
4. Variety only when the game mechanics make variety useful.
5. Emergency minimum food over optimal trade value when departure safety is at risk.

Trade profit should not prevent food safety.

A profitable trade route is invalid if the party cannot safely feed itself to reach or continue the route.

## Threshold doctrine

The repo should avoid hidden magic constants.

Food thresholds should be explicit and logged.

Recommended threshold concepts:

- `currentFoodDays`
- `minimumDepartureFoodDays`
- `targetFoodDays`
- `emergencyFoodDays`
- `routeEstimatedDays`
- `routeFoodBufferDays`

Departure should normally require:

```text
currentFoodDays >= max(minimumDepartureFoodDays, routeEstimatedDays + routeFoodBufferDays)
```

If route estimation is not reliable yet, use a conservative fixed target and record that route-aware estimation is still pending.

## Required evidence files

The branch should produce or reserve these evidence surfaces:

- `BlacksmithGuild_FoodProvisioningStatus.json`
- `BlacksmithGuild_FoodProvisioningDecision.json`
- `BlacksmithGuild_FoodProvisioningExecution.json`

## Required status fields

`BlacksmithGuild_FoodProvisioningStatus.json` should include:

- `town`
- `partySize`
- `currentFoodItems`
- `currentFoodUnits`
- `currentFoodDays`
- `gold`
- `inventoryWeight`
- `capacity`
- `availableCapacity`
- `routeTarget`
- `routeEstimatedDays`
- `routeFoodBufferDays`
- `minimumDepartureFoodDays`
- `targetFoodDays`
- `emergencyFoodDays`
- `status`
- `updatedAtUtc`

## Required decision fields

`BlacksmithGuild_FoodProvisioningDecision.json` should include:

- `town`
- `decision`
- `reason`
- `foodTargetMet`
- `departureAllowed`
- `recommendedPurchases`
- `estimatedCost`
- `estimatedWeight`
- `goldReserveAfterPurchase`
- `capacityAfterPurchase`
- `blockedReason`
- `nextBranch`
- `updatedAtUtc`

## Required execution fields

`BlacksmithGuild_FoodProvisioningExecution.json` should include:

- `town`
- `decision`
- `attempted`
- `success`
- `goldBefore`
- `goldAfter`
- `foodDaysBefore`
- `foodDaysAfter`
- `itemsBought`
- `totalCost`
- `totalWeight`
- `departureAllowedAfter`
- `failureClass`
- `updatedAtUtc`

## Branch outcomes

The food provisioning branch must end with exactly one classified outcome:

- `food_target_met`
- `food_bought_and_verified`
- `food_unavailable_in_market`
- `insufficient_gold_for_food`
- `insufficient_capacity_for_food`
- `market_read_failed`
- `execution_failed`
- `manual_intervention_required`

## Integration with route selection

Route selection must consume food provisioning state.

The next profit route is not valid if:

- food is below the route-safe threshold
- food provisioning failed without a safe override
- route travel days exceed the safe food buffer
- buying trade goods consumed the food budget
- horse/capacity decisions would reduce departure safety below threshold

## Integration with trade

Trade runs before food provisioning, but trade does not outrank food safety.

After trade buy/sell, the system must reassess food using the post-trade inventory and gold state.

If trade purchases leave too little gold or capacity for food, the town loop must classify the trade/logistics conflict and block departure or recommend correction.

## Integration with horses and capacity

Food provisioning runs before horse/capacity checks.

Horse/capacity decisions should consume post-food state, including:

- gold after food purchase
- capacity after food purchase
- route readiness after food purchase

Horses can improve route feasibility, but they do not replace food.

## Implementation boundaries

Do not claim departure is safe without verified food state.

Do not make trade profit override survival.

Do not select the next town until food provisioning has completed or blocked with an actionable reason.

Do not mutate food, gold, or inventory outside legal game mechanics.

## Product principle

Food provisioning must become a callable action branch.

When called, it must either buy food and prove the result, or block departure with a useful reason.
