#!/usr/bin/env python3
"""Dependency-free contracts for BlacksmithGuild E2E and sprint-capsule harness."""
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
      'agents':ROOT/'AGENTS.md','claude':ROOT/'CLAUDE.md','map':ROOT/'CODEBASE_MAP.md','manifest':ROOT/'.tbg/harness/manifest.json','skills':ROOT/'.tbg/skills/manifest.json','harness_skill':ROOT/'.tbg/skills/harness-maturity/SKILL.md',
      'operations':ROOT/'.tbg/harness/api/operations.json','profiles':ROOT/'.tbg/harness/e2e/profiles.json','consumers':ROOT/'.tbg/harness/consumer-handoffs.registry.json','artifacts':ROOT/'.tbg/harness/e2e-artifact-types.registry.json',
      'e2e_contract':ROOT/'.tbg/workflows/end-to-end-validation.contract.json','capsule_contract':ROOT/'.tbg/workflows/tbg-sprint-capsule.contract.json','profile_schema':ROOT/'.tbg/harness/schemas/e2e-validation-profiles.schema.json','result_schema':ROOT/'.tbg/harness/schemas/tbg-harness-result.schema.json','capsule_schema':ROOT/'.tbg/harness/schemas/tbg-sprint-capsule.schema.json',
      'ps_test':ROOT/'scripts/tbg/Test-TbgEndToEndHarness.ps1','ps_run':ROOT/'scripts/tbg/Invoke-TbgEndToEndValidation.ps1','ps_capsule':ROOT/'scripts/tbg/New-TbgSprintCapsule.ps1','skill_test':ROOT/'scripts/tbg/Test-TbgSkillRouting.ps1',
      'entry':ROOT/'docs/AI_HARNESS_ENTRYPOINT.md','posture':ROOT/'docs/END_TO_END_TESTING_POSTURE.md','handoff':ROOT/'docs/MACHINE_READABLE_HANDOFF.md','project':ROOT/'src/BlacksmithGuild/BlacksmithGuild.csproj','status_cmd':ROOT/'ForgeAgentStatus.cmd'}
    for name,path in paths.items(): require(path.is_file(),f'missing {name}: {path.relative_to(ROOT)}')
    require('.tbg/skills/manifest.json' in read(paths['agents']),'AGENTS must route through canonical .tbg skill manifest')
    require('.tbg/skills/manifest.json' in read(paths['claude']),'CLAUDE adapter must route through canonical .tbg skill manifest')
    manifest=load(paths['manifest']);profiles=load(paths['profiles']);operations=load(paths['operations']);consumers=load(paths['consumers']);artifacts=load(paths['artifacts'])
    require(manifest['schema']=='tbg.harness.manifest.v1','harness manifest version')
    for key in ('endToEndProfiles','endToEndContract','endToEndEntrypoint','sprintCapsuleContract','consumerHandoffRegistry'): require(key in manifest['paths'],f'manifest missing {key}')
    require(profiles['schema']=='tbg.e2e-profiles.v1','profile version');require(profiles['defaultProfile']=='default-static','default profile');require(profiles['posture']['endToEndDefaultRequired'] is True,'E2E default');require(profiles['posture']['gameMutationDefault'] is False,'mutation default false')
    journey_ids={j['id'] for j in profiles['journeys']}
    for journey in profiles['journeys']:
        if journey.get('script'): require((ROOT/journey['script']).is_file(),f"missing journey script {journey['script']}")
    for profile in profiles['profiles']:
        for journey in profile['journeyIds']: require(journey in journey_ids,f'unknown journey {journey}')
    operation_ids=[x['id'] for x in operations['operations']];require(len(operation_ids)==len(set(operation_ids)),'duplicate operations')
    consumer_ids={x['id'] for x in consumers['consumers']};require({'agent-switchboard','sysadminsuite'}<=consumer_ids,'consumer registry incomplete')
    require(artifacts['trackedRuntimeEvidenceAllowed'] is False,'runtime artifacts must remain untracked')
    capsule=load(paths['capsule_schema']);require({'consumers','proof','git','nextCommand'}<=set(capsule['required']),'capsule schema fields')
    agents=read(paths['agents']);require(len(agents.splitlines())<=110,'AGENTS compact ceiling')
    for token in ('CODEBASE_MAP.md','end-to-end-validation.contract.json','tbg-sprint-capsule.contract.json','SysAdminSuite'): require(token in agents,f'AGENTS missing {token}')
    skill=read(paths['harness_skill']);require('default-static' in skill and 'tbg.sprint-capsule.v1' in skill,'harness skill not integrated')
    require("Condition=\"'$(Configuration)' == 'Release'\"" in read(paths['project']),'Release install seam must stay explicit');require('-c Debug' in read(paths['entry']),'Debug build guidance')
    for key in ('ps_test','ps_run','ps_capsule'):
        raw=paths[key].read_bytes();require(raw.startswith(b'\xef\xbb\xbf'),f'PowerShell BOM missing: {paths[key].relative_to(ROOT)}')
    run_text=read(paths['ps_run'])
    for token in ('TimeoutSeconds','taskkill.exe','LastWriteTimeUtc','dotnet','Debug','sprint-capsule.json'): require(token in run_text,f'runner missing {token}')
    new_paths=[p for key,p in paths.items() if key not in {'manifest','skills','skill_test','project','status_cmd'}]
    text='\n'.join(read(p) for p in new_paths)
    for token in ('OPENAI_'+'API_KEY','ANTHROPIC_'+'API_KEY','DEEPSEEK_'+'API_KEY','C:\\'+'Users\\Cheex','/home/'+'cheex'): require(token not in text,f'forbidden token {token}')
    for path in new_paths:
        raw=path.read_bytes();require(all(not line.endswith((b' ',b'\t')) for line in raw.splitlines()),f'trailing whitespace {path.relative_to(ROOT)}')
    print('PASS: BlacksmithGuild E2E harness contracts');return 0
if __name__=='__main__':
    try: raise SystemExit(main())
    except AssertionError as exc: print(f'FAIL: {exc}',file=sys.stderr);raise SystemExit(1)
