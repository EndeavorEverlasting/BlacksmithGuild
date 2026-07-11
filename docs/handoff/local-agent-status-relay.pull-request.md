# PR Summary: Local Agent Status Relay

## Summary

Adds a local, read-only evidence relay so the operator can produce a compact ChatGPT/Codex packet with one command instead of manually copying several terminal sections.

## Added

```text
ForgeAgentStatus.cmd
scripts/tbg/New-TbgChatPacket.ps1
docs/handoff/local-agent-status-relay.md
```

## Operator command

```cmd
ForgeAgentStatus.cmd -PrNumber 43
```

Optional GitHub relay:

```cmd
ForgeAgentStatus.cmd -PrNumber 43 -PostPrComment
```

## Artifacts written

```text
artifacts/latest/tbg-chat-packet.md
artifacts/latest/tbg-chat-packet.json
```

## Boundary

This is static/read-only except for writing ignored `artifacts/latest` packet files and optionally posting a PR comment through `gh`.

It does not launch Bannerlord, run ForgeReboot, write command inbox files, mutate saves, delete branches, clean worktrees, or claim runtime proof.

## Local validation still required

```cmd
ForgeAgentStatus.cmd -PrNumber 43
```

Then inspect:

```text
artifacts/latest/tbg-chat-packet.md
artifacts/latest/tbg-chat-packet.json
```
