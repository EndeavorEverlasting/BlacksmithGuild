# BlacksmithGuild C# Mod Rules

```text
[TBG | C# Mod Rules | scope: src/BlacksmithGuild]
```

## Core doctrine

Automate the hands, not the consequences.

Do not add free gold, resources, XP, travel, stamina, or save mutation unless the sprint explicitly allows disposable-test mutation.

## Runtime proof

C# behavior changes require proof beyond compilation when they affect:

- launcher or Continue automation
- character creation traversal
- command inbox parsing
- hotkeys
- inventory or stamina mutation
- route automation
- runtime logs or status JSON

## Search discipline

Use MCP/LSP symbol lookup where possible for:

- definitions
- references
- call chains
- diagnostics
- type information

## Evidence surfaces

Runtime evidence usually lives in:

```text
BlacksmithGuild_Phase1.log
BlacksmithGuild_Launch.log
BlacksmithGuild_Status.json
BlacksmithGuild_CommandInbox.json
```

Do not write to command inbox from a harness-only sprint.
