# Proof Claim Discipline

## Purpose

Proof claim discipline prevents agents from turning partial evidence into inflated product claims.

The repo must distinguish between build success, verifier success, runtime readiness, visible runtime behavior, and product completion.

## Proof ladder

The default proof ladder is:

```text
Build PASS
Verifier PASS
Static PASS
Runtime PASS
Visible PASS
Product PASS
```

## Claim boundaries

### Build PASS

Supports:

```text
code compiled
project loaded enough to build
```

Does not support:

```text
runtime behavior
game launched
command bridge worked
automation succeeded
```

### Verifier PASS

Supports:

```text
contract anchors exist
static doctrine is present
expected text or file shape exists
```

Does not support:

```text
runtime behavior
live proof
save mutation
product completion
```

### Runtime PASS

Supports:

```text
live runtime surface accepted a bounded command
fresh runtime evidence was produced
```

Does not support by itself:

```text
visible gameplay success
campaign route completion
movement proof
market/travel/smithing completion
```

### Visible PASS

Supports:

```text
observable runtime state changed or visible mechanism was confirmed
```

Does not support by itself:

```text
full product loop completion
unbounded automation success
future action success
```

### Product PASS

Requires:

```text
objective met
terminal evidence present
nextActionRequired=false or terminal stop recorded
fresh artifacts match current branch/head
claim boundaries documented
```

## Forbidden inflation examples

Forbidden unless supported by matching evidence:

```text
launcher success proves automation
command ACK proves campaign route completion
config written proves game loaded the config
movement intent proves movement
static verifier proves runtime safety
checkpoint proves product completion
```

## Required phrasing

Agents should write:

```text
This proves X.
This does not prove Y.
Next evidence required is Z.
```

## Stale evidence rule

Evidence is stale when:

```text
it predates the current relevant code change
it came from another branch or head SHA
it lacks a timestamp
it lacks a run id when run id is required
it was copied from an older proof bundle
```

Stale evidence may explain history. It cannot close a current sprint.

## Unsupported claim blocker

If a PR body, doc, or generated feedback claims product completion without terminal evidence, the claim must be treated as a blocker.

Recommended future verifier:

```text
scripts/verify-proof-claim-discipline-contract.ps1
```

The verifier should search for known inflation phrases and require nearby allowed/forbidden claim language.
