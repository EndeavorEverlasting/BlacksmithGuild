# Skill: operator-terminal-environment

Use this skill when a sprint touches the local operator shell, terminal sessions, agent console layout, command relay ergonomics, or the relationship between WezTerm, tmux, Neovim, voice input, and BlacksmithGuild repo-local harness commands.

## Source fact

WezTerm is a GPU-accelerated cross-platform terminal emulator and multiplexer written in Rust. Its user-facing docs live at `https://wezterm.org/`, and installation guidance lives at `https://wezterm.org/installation`.

BlacksmithGuild should treat WezTerm as an operator environment candidate, not as repo runtime code.

## Use when

- Designing a Windows-friendly operator terminal setup for `ForgeAgentStatus`, future `tbg-axi`, GitHub CLI, PowerShell, and local runtime proof commands.
- Deciding how terminal sessions should be named, grouped, logged, or restored during repo hygiene, runtime proof, and stale PR replay work.
- Explaining how WezTerm, tmux, Treehouse, Firstmate, Neovim, and voice input cooperate without being vendored into BlacksmithGuild.
- Adding docs or contracts that describe an operator shell profile, command palette, or session topology.

## Do not use when

- Editing runtime gameplay behavior.
- Launching Bannerlord or running ForgeReboot.
- Making WezTerm, tmux, Neovim, or voice input a hard dependency of BlacksmithGuild.
- Adding machine-local terminal config, personal paths, secrets, fonts, private shell history, or generated terminal logs to the repo.
- Claiming runtime proof because a terminal session was organized successfully.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/operator-terminal-environment.contract.json`
4. `docs/architecture/compendium-preservation-and-rewarding-sprint.md`
5. `docs/handoff/local-agent-status-relay.md`
6. `docs/handoff/local-agent-status-relay.pull-request.md`

## Owned scope

- `.tbg/skills/operator-terminal-environment/SKILL.md`
- `.tbg/workflows/operator-terminal-environment.contract.json`
- architecture or handoff docs that describe local operator terminal/session design
- docs that evolve `ForgeAgentStatus` or future `tbg-axi` command usage

## Forbidden scope

- `src/**` gameplay/runtime edits.
- Launcher scripts or command inbox writes unless a separate launcher/runtime sprint owns them.
- Installing external terminal/editor tools as part of a documentation sprint.
- Committing user-specific WezTerm config, terminal layouts, local shell history, screenshots, fonts, or private machine paths.

## Layering rule

Treat terminal tooling as the operator shell layer above the repo:

```text
WezTerm / tmux / Neovim / voice input
        -> operator shell, session layout, prompt throughput, local command ergonomics

ForgeAgentStatus / future tbg-axi
        -> repo-local evidence packet, proof status, next command, PR relay

.tbg workflows / skills / AGENTS.md
        -> repo-specific contracts, boundaries, and validation doctrine
```

Do not invert the layers. BlacksmithGuild should expose clean commands and packets that work well in WezTerm; it should not vendor WezTerm or depend on a specific terminal emulator.

## Adoption sequence

1. Document the desired session topology before installing or changing terminal config.
2. Keep `ForgeAgentStatus.cmd` and future `tbg-axi` output compact enough to read in a terminal pane.
3. Prefer stable pane/session names such as `tbg-main`, `tbg-pr43-proof`, `tbg-pr45-docs`, `tbg-stale-replay`, and `tbg-artifacts`.
4. Route long details to artifacts or PR comments, not raw terminal scrollback.
5. If a terminal profile is later added, keep it as an example or template with no user secrets and no mandatory dependency.

## Done gate

A terminal-environment sprint is done only when:

- WezTerm's role is documented as an operator shell candidate;
- external tools remain outside the repo unless an install sprint explicitly owns them;
- repo-local commands remain terminal-agnostic;
- no machine-local secrets, fonts, shell history, or generated terminal evidence are committed;
- validation commands or exact skipped checks are recorded;
- one exact next command is provided.

## Common traps

- Treating WezTerm adoption as a runtime feature.
- Hiding proof gaps behind a nicer terminal layout.
- Making Windows operator ergonomics depend on WSL/tmux before that environment is deliberately chosen.
- Committing personal terminal configuration instead of repo-safe example guidance.
- Dumping huge raw JSON into terminal output instead of writing artifacts and compact summaries.

## Handoff output

End with:

- terminal role;
- changed surfaces;
- external tools intentionally not installed;
- validation run;
- skipped checks;
- remaining risks;
- exact next command.
