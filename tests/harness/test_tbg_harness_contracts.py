#!/usr/bin/env python3
"""Dependency-free contracts for the BlacksmithGuild AI harness."""
from __future__ import annotations
import json
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def require(value: bool, message: str)->None:
    if not value: raise AssertionError(message)
def read(path: Path)->str: return path.read_text(encoding='utf-8-sig')
def load(path: Path): return json.loads(read(path))
def main()->int:
    paths={
      'agents':ROOT/'AGENTS.md','claude':ROOT/'CLAUDE.md','map':ROOT/'CODEBASE_MAP.md','family':ROOT/'.ai/agent-contract.json',
      'manifest':ROOT/'harness/api/agent-capability-manifest.json','routing':ROOT/'harness/api/agent-routing-manifest.json','api':ROOT/'harness/api/tbg-harness-api.json','artifacts':ROOT/'harness/api/artifact-types.json','e2e':ROOT/'harness/e2e/e2e-profiles.json',
      'workflow':ROOT/'harness/workflows/tbg-sprint-capsule.yaml','capsule_schema':ROOT/'schemas/harness/tbg-sprint-capsule.schema.json','result_schema':ROOT/'schemas/harness/tbg-harness-result.schema.json',
      'ps_validator':ROOT/'scripts/Test-TbgAiHarness.ps1','ps_e2e':ROOT/'scripts/Invoke-TbgHarnessE2E.ps1','ps_capsule':ROOT/'scripts/New-TbgSprintCapsule.ps1',
      'entry':ROOT/'docs/AI_HARNESS_ENTRYPOINT.md','posture':ROOT/'docs/END_TO_END_TESTING_POSTURE.md','handoff':ROOT/'docs/MACHINE_READABLE_HANDOFF.md','readme':ROOT/'README.md','ignore':ROOT/'.gitignore','project':ROOT/'src/BlacksmithGuild/BlacksmithGuild.csproj','forge':ROOT/'forge.ps1'}
    for name,path in paths.items(): require(path.is_file(),f'missing {name}: {path.relative_to(ROOT)}')
    manifest=load(paths['manifest']);routing=load(paths['routing']);api=load(paths['api']);artifacts=load(paths['artifacts']);e2e=load(paths['e2e']);family=load(paths['family'])
    require(manifest['schema_version']=='tbg-agent-capability-manifest/v1','manifest version')
    require(routing['ambiguity_policy']=='fail-closed-to-repository-sprint','routing must fail closed')
    require(e2e['default_profile']=='default-static','static default')
    require(e2e['posture']['end_to_end_default_required'] is True,'E2E default required')
    require(e2e['posture']['game_mutation_default'] is False,'mutation default false')
    require(artifacts['tracked_runtime_evidence_allowed'] is False,'runtime evidence untracked')
    require(family['canonical_family_root']=='EndeavorEverlasting/AgentSwitchboard','family root')
    capabilities=[x['id'] for x in manifest['capabilities']];skills=[x['id'] for x in manifest['skills']];operations=[x['id'] for x in api['operations']]
    require(len(capabilities)==len(set(capabilities)),'duplicate capabilities');require(len(skills)==len(set(skills)),'duplicate skills')
    for item in manifest['capabilities']: require((ROOT/item['path']).is_file(),f"missing capability {item['path']}")
    for item in manifest['skills']:
        require((ROOT/item['path']).is_file(),f"missing skill {item['path']}")
        for dep in item['capability_dependencies']: require(dep in capabilities,f'unknown dependency {dep}')
    signals=set()
    for route in routing['routes']:
        for signal in route['signals']:
            key=signal.casefold();require(key not in signals,f'duplicate signal {signal}');signals.add(key)
        target=route['target'];require(target['id'] in (skills if target['kind']=='skill' else operations),f"unknown route target {target['id']}")
    journey_ids={x['id'] for x in e2e['journeys']}
    for journey in e2e['journeys']: require((ROOT/journey['script']).is_file(),f"missing journey {journey['script']}")
    for profile in e2e['profiles']:
        for journey in profile['journey_ids']: require(journey in journey_ids,f'unknown journey {journey}')
    agents=read(paths['agents']).casefold()
    for token in ('end-to-end proof is the default merge target','disposable campaign','command ack','machine-readable handoffs','sprint capsule'): require(token in agents,f'AGENTS missing {token}')
    require("Condition=\"'$(Configuration)' == 'Release'\"" in read(paths['project']),'Release install seam')
    require('-c Debug' in read(paths['entry']),'Debug build guidance')
    required=set(load(paths['capsule_schema'])['required']);require({'consumers','proof','git_state','next_command'}<=required,'capsule key fields')
    handoff=read(paths['handoff']);require('AgentSwitchboard' in handoff and 'SysAdminSuite' in handoff,'consumer handoffs')
    all_text='\n'.join(read(p) for p in paths.values())
    for token in ('OPENAI_'+'API_KEY','ANTHROPIC_'+'API_KEY','DEEPSEEK_'+'API_KEY','C:\\'+'Users\\Cheex','/home/'+'cheex'): require(token not in all_text,f'forbidden token {token}')
    for path in paths.values():
        raw=path.read_bytes();require(all(not line.endswith((b' ',b'\t')) for line in raw.splitlines()),f'trailing whitespace {path.relative_to(ROOT)}')
    print('PASS: BlacksmithGuild AI harness contracts');return 0
if __name__=='__main__':
    try: raise SystemExit(main())
    except AssertionError as exc: print(f'FAIL: {exc}',file=sys.stderr);raise SystemExit(1)
