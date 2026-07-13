# Green-light execution policy

## Purpose

Proof discipline must prevent overclaiming without becoming an execution prohibition. When the operator asks for the current, best, strongest, or most capable way to test the application, prefer the strongest available bounded operational workflow, including a workflow on a current branch or open pull request when its authority and safety boundary are clear.

An open pull request is a delivery state. It is not automatically an execution prohibition.

## Execution gate

A workflow may be recommended or run when:

- its repository, branch, and exact head are identified;
- its command surface exists;
- its owned scope includes the requested action;
- its safety boundaries are explicit;
- it preserves unrelated dirty work or selects an isolated worktree;
- it does not require destructive repository operations;
- the operator requested the corresponding test, launch, validation, or runtime action.

Use this decision rule:

```text
green execution authority + incomplete proof
    = run the workflow and collect fresh proof

missing execution authority or unsafe mutation
    = block and name the exact missing gate
```

Missing exact-head CI, missing local runtime evidence, or an open pull request may lower the proof level that can be claimed. Those conditions do not automatically prohibit a bounded local test.

## Proof reporting

Do not convert:

```text
This run cannot yet prove gameplay completion.
```

into:

```text
Do not run the available launcher or runtime harness.
```

Report application-test gates independently:

1. build;
2. deploy;
3. launcher;
4. process handoff;
5. runtime attach;
6. campaign readiness;
7. command acknowledgement;
8. behavior observed;
9. live product result.

Failure or absence at a higher gate does not erase successful lower gates.

## Path selection

When multiple test paths exist, present them in this order:

1. strongest current bounded operational path;
2. exact proof ceiling and current-head evidence gap;
3. merged-main fallback;
4. narrow manual fallback.

Avoid permission theater. A request to test, launch, validate, exercise, or certify the application grants authority to use the repository workflow designed for that purpose, subject to that workflow's existing safety boundaries.

## Repository placement

`AGENTS.md` carries only the universal summary and a pointer to this policy. Scoped launcher, runtime, operator-control, and evidence skills own the executable details and validators. Mutable branch, pull-request, worktree, and runtime facts remain in current-state packets and generated evidence.
