# Registered PR Lifecycle Canary

This file is the end-to-end proof surface for the registered default-branch PR lifecycle workflow.

Expected sequence:

```text
draft PR opened
required platform-neutral checks pass
/reconcile-pr-lifecycle comment is posted
trusted lifecycle workflow promotes the draft
ready-for-review event triggers a second lifecycle pass
exact-head squash merge completes
lifecycle JSON artifacts are retained
```

No direct readiness or merge API call belongs to this canary.

Installed-game Windows or Linux checks, Bannerlord launch, gameplay behavior, branch deletion, force operations, and history rewrite remain outside this proof.
