# Test Duration Doctrine

## Purpose

The project uses CMD and PowerShell entry points to operate Bannerlord up to a bounded observation point, collect evidence, classify the next repair target, and stop. They are not supposed to become unattended long-haul game runs by default.

The default test posture is fast, bounded, and interruptible.

## Core rule

**Thirty seconds is the default test-duration budget for every repo test, verifier, smoke run, CMD wrapper, and observation harness where a shorter bounded run can answer the question.**

A test that needs more than 30 seconds must opt in explicitly and must say why.

## Default budget

| Class | Default budget | Rule |
|---|---:|---|
| Static contract verifier | 30 seconds or less | Should inspect files, contracts, docs, manifests, and syntax without launching the game. |
| Smoke test | 30 seconds or less | Should prove one narrow seam, then stop. |
| CMD wrapper test | 30 seconds or less | Should delegate to a bounded harness instead of owning its own long wait. |
| Launcher/UI observation | 30 seconds or less | Should prove launcher/window/context/ack state, then stop. |
| Runtime evidence probe | 30 seconds or less when possible | Should gather one observation slice and classify the next action. |
| Live certificate | Explicit longer opt-in only | Must be named as a live cert and must not be treated as the default path. |

## Exception rule

Longer runs are allowed only when all of the following are true:

1. The caller uses an explicit long-run parameter or named cert profile.
2. The script logs the selected budget and the reason for exceeding 30 seconds.
3. The output clearly distinguishes `contract/pass` from `runtime/pass`.
4. The run has a stop condition, timeout, or operator-controlled cancel path.
5. The run does not mutate personal saves or commit runtime evidence.

If those conditions are not true, the script should stay inside the 30-second default.

## Design principle

The default harness should answer this question:

> What can we learn safely in 30 seconds that tells us what to fix next?

It should not try to answer:

> Can the entire autonomous gameplay loop complete?

That larger question belongs to named live-cert runs only.

## Required behavior for future refactors

Any new or refactored test entry point should use a shared duration policy instead of inventing its own timeout constants.

Preferred parameter names:

- `-TimeoutSec`
- `-MaxRuntimeSec`
- `-BudgetSec`
- `-CertProfile`
- `-LiveCert`

Default values should resolve to 30 seconds unless the script is explicitly a long-running cert harness.

## Bad patterns

Do not add default waits like these without a doctrine-backed exception:

- `Start-Sleep -Seconds 60`
- `Start-Sleep -Seconds 120`
- `AttachWaitSec = 600`
- `MaxRuntimeMinutes = 30`
- polling loops with no 30-second default budget
- CMD files that hide long waits behind another script

These are sometimes valid for live certs, but they are not valid defaults.

## Good patterns

Good bounded tests do this:

1. Start from known state.
2. Run one narrow command or observation loop.
3. Stop at 30 seconds by default.
4. Write a small evidence artifact or console summary.
5. Classify the next action as pass, fail, blocked, or needs-long-cert.

## Repo policy

When an agent touches a test, verifier, CMD wrapper, or runner, it must check whether that entry point has a 30-second default path. If not, the agent must either fix it in that sprint or mark the long duration as a known gap with a concrete file and parameter name.

The doctrine is not aspirational. It is a merge expectation.
