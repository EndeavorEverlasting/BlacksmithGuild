# Governor visible-trade live runtime

This directory contains sanitized, reviewable evidence from the live governor
travel-to-trade certification. Raw game logs, screenshots, dumps, and personal
filesystem paths remain local.

The first attached run loaded the exact approved save, selected
`food_quantity`, issued visible travel to Quyaz, moved the party, and confirmed
the target settlement. The buy proof gate then blocked completion because the
fallback `SellItemsAction` increased gold and added no food. See
`failure-01-sell-direction.json` for the bounded observation, cause, and repair.

Later files in this directory record the post-repair rerun. A command
acknowledgement, route intent, or settlement arrival is never treated as a
completed trade without a fresh positive inventory delta and negative gold
delta.
