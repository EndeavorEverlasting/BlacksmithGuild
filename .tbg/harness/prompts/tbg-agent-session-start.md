# TBG Agent Session Start Prompt

```text
[TBG | Session Start | Local Agent Harness]
```

At session start, identify:

- repo
- branch
- PR or sprint
- lane
- owned scope
- forbidden scope
- expected artifacts
- validation commands

Read first:

```text
CLAUDE.md
.tbg/harness/manifest.json
.tbg/workflows/local-mcp-code-intelligence.contract.json
```

Then inspect the most relevant path-local `CLAUDE.md` file before editing.

Do not ask the user to repeat context that exists in these files.
