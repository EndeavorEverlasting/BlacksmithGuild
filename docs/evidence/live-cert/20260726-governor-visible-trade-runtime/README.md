# Governor visible-trade live runtime

This directory contains sanitized, reviewable evidence from the live governor
travel-to-trade certification. Raw game logs, screenshots, dumps, and personal
filesystem paths remain local.

The first attached run loaded the exact approved save, selected
`food_quantity`, issued visible travel to Quyaz, moved the party, and confirmed
the target settlement. The buy proof gate then blocked completion because the
fallback `SellItemsAction` increased gold and added no food. See
`failure-01-sell-direction.json` for the bounded observation, cause, and repair.

The post-repair rerun at source commit `56fa387` loaded that exact save through
the real launcher, selected the same food priority, moved the party to Quyaz,
and bought one Butter. Inventory changed from `0` to `1` and gold changed from
`1000` to `960`. The same governor activity ID is retained across selection,
dispatch, Food adapter, travel, settlement confirmation, and trade completion.
The engine toggle was then returned to Manual while the game remained running
for player takeover. See `success-01-visible-food-buy.json`.

A command
acknowledgement, route intent, or settlement arrival is never treated as a
completed trade without a fresh positive inventory delta and negative gold
delta.
