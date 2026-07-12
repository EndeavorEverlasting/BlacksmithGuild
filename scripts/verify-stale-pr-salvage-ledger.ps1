param(
    [string]$LedgerPath = '',
    [switch]$VerifyRemoteHeads
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($LedgerPath)) {
    $LedgerPath = Join-Path $repoRoot '.tbg\harness\stale-pr-salvage-ledger.json'
}

function Assert-Contract {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "Stale PR salvage ledger contract failed: $Message"
    }
}

function Assert-NonEmptyArray {
    param(
        [object[]]$Value,
        [string]$Name
    )

    Assert-Contract -Condition ($null -ne $Value -and @($Value).Count -gt 0) -Message "$Name must be a non-empty array."
    foreach ($item in @($Value)) {
        Assert-Contract -Condition (-not [string]::IsNullOrWhiteSpace([string]$item)) -Message "$Name contains a blank item."
    }
}

Assert-Contract -Condition (Test-Path -LiteralPath $LedgerPath -PathType Leaf) -Message "ledger is missing: $LedgerPath"
$raw = Get-Content -LiteralPath $LedgerPath -Raw
Assert-Contract -Condition ($raw -notmatch '(?i)C:\\Users\\') -Message 'ledger must not contain a machine-local user path.'

try {
    $ledger = $raw | ConvertFrom-Json
}
catch {
    throw "Stale PR salvage ledger is not valid JSON: $($_.Exception.Message)"
}

Assert-Contract -Condition ($ledger.schema -eq 'tbg.stale-pr-salvage-ledger.v1') -Message 'unexpected schema.'
Assert-Contract -Condition ($ledger.repository -eq 'EndeavorEverlasting/BlacksmithGuild') -Message 'unexpected repository.'
Assert-Contract -Condition ([string]$ledger.baseline.mainSha -match '^[0-9a-f]{40}$') -Message 'baseline.mainSha must be a full SHA.'
Assert-Contract -Condition ([string]$ledger.baseline.activeReplacementHeadAtSnapshot -match '^[0-9a-f]{40}$') -Message 'active replacement head must be a full SHA.'
Assert-Contract -Condition ($ledger.baseline.agentStatusRelay.pr -eq 46) -Message 'merged agent status relay PR #46 must be recorded.'
Assert-Contract -Condition ($ledger.baseline.agentStatusRelay.mergeSha -eq '60daeb4c8472027ee7eda9d532b9fc01541605d0') -Message 'agent status relay merge SHA drifted.'
Assert-NonEmptyArray -Value @($ledger.baseline.agentStatusRelay.paths) -Name 'baseline.agentStatusRelay.paths'
Assert-NonEmptyArray -Value @($ledger.baseline.agentStatusRelay.capabilities) -Name 'baseline.agentStatusRelay.capabilities'
Assert-NonEmptyArray -Value @($ledger.preservationPolicy.closeRequires) -Name 'preservationPolicy.closeRequires'
Assert-NonEmptyArray -Value @($ledger.preservationPolicy.remoteBranchDeleteRequires) -Name 'preservationPolicy.remoteBranchDeleteRequires'

$expectedHeads = [ordered]@{
    2 = '61090349037c89d4bcbc1c0e3fd4a3651333e7e6'
    5 = '9ec17ac3fc4bbc6acc4f1f1d472b9e878a91f247'
    6 = '2b5b7e104d1ac095cef9db738e0b56beec939643'
    8 = 'd8a0e0e209846c230e129bb82f288978d8a757aa'
    9 = 'ef0c95ca4f541cca579efe81d039559c1724fb8c'
    20 = '2839b37e0ff6cd9eb24d649a5b6d17fb14c738b0'
    24 = 'e3c0b14ee3918c87f3e28824ac08a80e673a3bec'
    28 = '1655925e5124c3e0b7a3567766cf3dd216da8eda'
    29 = 'c8bab9873bfb5d6abe041b09040752dc2ff6f169'
    30 = 'b6f126b24f296bb01afeec455204d29a3a53b088'
    31 = 'c4a6c93e90bab382f3bbc58bf2d0b21623e59745'
    32 = 'd004aead5b482005bf03e77e8b181a11680b6f46'
    33 = '340602946dee8eab4b4defd1e37e2be3a5569090'
    34 = '63610beefdda0beef269ee4f3f8665cc04e0be5a'
    35 = '4b291a96b2763988d6c4a37feabe473cd88978b3'
    38 = 'e618349b7575dc6379cb7a8b378df6ec5be4d282'
}

$entries = @($ledger.entries)
Assert-Contract -Condition ($entries.Count -eq $expectedHeads.Count) -Message "expected $($expectedHeads.Count) entries, found $($entries.Count)."
$entryNumbers = @($entries | ForEach-Object { [int]$_.number })
Assert-Contract -Condition ((@($entryNumbers | Sort-Object -Unique)).Count -eq $entries.Count) -Message 'PR numbers must be unique.'

foreach ($pair in $expectedHeads.GetEnumerator()) {
    $entry = @($entries | Where-Object { [int]$_.number -eq [int]$pair.Key })
    Assert-Contract -Condition ($entry.Count -eq 1) -Message "PR #$($pair.Key) must appear exactly once."
    $item = $entry[0]

    Assert-Contract -Condition ([string]$item.headSha -eq [string]$pair.Value) -Message "PR #$($pair.Key) head SHA drifted."
    Assert-Contract -Condition ([string]$item.url -eq "https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/$($pair.Key)") -Message "PR #$($pair.Key) URL is wrong."
    Assert-Contract -Condition (-not [string]::IsNullOrWhiteSpace([string]$item.title)) -Message "PR #$($pair.Key) title is blank."
    Assert-Contract -Condition (-not [string]::IsNullOrWhiteSpace([string]$item.sourceBase)) -Message "PR #$($pair.Key) source base is blank."
    Assert-Contract -Condition (-not [string]::IsNullOrWhiteSpace([string]$item.headBranch)) -Message "PR #$($pair.Key) branch is blank."
    Assert-NonEmptyArray -Value @($item.usefulShas) -Name "PR #$($pair.Key) usefulShas"
    Assert-NonEmptyArray -Value @($item.utility) -Name "PR #$($pair.Key) utility"
    Assert-NonEmptyArray -Value @($item.collision.paths) -Name "PR #$($pair.Key) collision.paths"
    Assert-Contract -Condition (@('low', 'medium', 'high') -contains [string]$item.collision.risk) -Message "PR #$($pair.Key) collision risk is invalid."
    Assert-Contract -Condition (-not [string]::IsNullOrWhiteSpace([string]$item.collision.reason)) -Message "PR #$($pair.Key) collision reason is blank."
    Assert-Contract -Condition (-not [string]::IsNullOrWhiteSpace([string]$item.replacement.disposition)) -Message "PR #$($pair.Key) disposition is blank."
    Assert-Contract -Condition (-not [string]::IsNullOrWhiteSpace([string]$item.replacement.status)) -Message "PR #$($pair.Key) replacement status is blank."
    Assert-NonEmptyArray -Value @($item.replacement.validation) -Name "PR #$($pair.Key) replacement.validation"
    Assert-NonEmptyArray -Value @($item.retainBranchUntil) -Name "PR #$($pair.Key) retainBranchUntil"

    $uniqueUsefulShas = @($item.usefulShas | Sort-Object -Unique)
    Assert-Contract -Condition ($uniqueUsefulShas.Count -eq @($item.usefulShas).Count) -Message "PR #$($pair.Key) usefulShas contains duplicates."
    foreach ($sha in @($item.usefulShas)) {
        Assert-Contract -Condition ([string]$sha -match '^[0-9a-f]{40}$') -Message "PR #$($pair.Key) has an invalid useful SHA: $sha"
    }
}

$closePhases = @($ledger.safeCloseOrder)
Assert-Contract -Condition ($closePhases.Count -gt 0) -Message 'safeCloseOrder must not be empty.'
$phaseSequences = @($closePhases | ForEach-Object { [int]$_.sequence })
Assert-Contract -Condition ((@($phaseSequences | Sort-Object -Unique)).Count -eq $closePhases.Count) -Message 'safeCloseOrder sequence numbers must be unique.'
$closeNumbers = @($closePhases | ForEach-Object { @($_.prs) } | ForEach-Object { [int]$_ })
Assert-Contract -Condition ($closeNumbers.Count -eq $expectedHeads.Count) -Message 'safeCloseOrder must include every tracked PR exactly once.'
Assert-Contract -Condition ((@($closeNumbers | Sort-Object -Unique)).Count -eq $expectedHeads.Count) -Message 'safeCloseOrder contains a duplicate or missing PR.'
foreach ($number in $expectedHeads.Keys) {
    Assert-Contract -Condition ($closeNumbers -contains [int]$number) -Message "safeCloseOrder is missing PR #$number."
}

if ($VerifyRemoteHeads) {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    Assert-Contract -Condition ($null -ne $gh) -Message 'gh is required for -VerifyRemoteHeads.'

    foreach ($pair in $expectedHeads.GetEnumerator()) {
        $remote = & gh pr view $pair.Key --repo $ledger.repository --json number,headRefOid 2>$null
        Assert-Contract -Condition ($LASTEXITCODE -eq 0) -Message "gh could not read PR #$($pair.Key)."
        $remoteObject = $remote | ConvertFrom-Json
        Assert-Contract -Condition ([string]$remoteObject.headRefOid -eq [string]$pair.Value) -Message "remote head for PR #$($pair.Key) no longer matches the ledger."
    }
}

Write-Host "PASS: stale PR salvage ledger covers $($entries.Count) PRs with exact heads, useful SHAs, collision dispositions, retention gates, and safe close order."
if ($VerifyRemoteHeads) {
    Write-Host 'PASS: all recorded heads match GitHub.'
}
