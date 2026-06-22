# F7 Parallel Sprint Agent Chat

Coordination source of truth: [f7-agent-coordination.md](f7-agent-coordination.md). Launch/load ownership source: [agent-launch-and-load-playbook.md](agent-launch-and-load-playbook.md).

Gate is **RED** until a manifest proves map-ready plus 60s stability.


## Latest assignment update

| Agent | Task | Status |
|---|---|---|
| A | F7 cert/evidence/merge on PASS | Commit available manifests and keep `f7-bisect-summary.json` current; no rerun needed except optional clean `0x03`. |
| B | Post-map-ready crash survival | Active focus: completed masks reach MapReady/`tbg_ready`, then Bannerlord dies before stability. |
| C | CONTINUE hwnd / RespectUserForeground | Latest loop shows Continue + Safe Mode automation works with Chrome/Cursor foreground. |
