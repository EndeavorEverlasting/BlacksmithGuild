param(
    [string]$ContractId = "mcp-symbol-smoke",
    [string]$McpCommand = "",
    [int]$TimeoutSeconds = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Find-TbgRepoRoot {
    $cursor = (Get-Location).Path
    while ($true) {
        if (Test-Path -LiteralPath (Join-Path $cursor ".tbg/harness/manifest.json")) { return $cursor }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $cursor) { throw "Could not locate repo root." }
        $cursor = $parent
    }
}

function Resolve-TbgTool {
    param([string]$RepoRoot, [string[]]$Names)
    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd) { return $cmd.Source }
    }
    foreach ($name in $Names) {
        $local = Join-Path $RepoRoot (".local/mcp-tools/" + $name)
        if (Test-Path -LiteralPath $local) { return $local }
        if (-not $name.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase)) {
            $localExe = Join-Path $RepoRoot (".local/mcp-tools/" + $name + ".exe")
            if (Test-Path -LiteralPath $localExe) { return $localExe }
        }
    }
    return $null
}

function New-SmokeQuery {
    param([string]$Question, [string]$Target, [string]$State, [string]$Note, [object[]]$Evidence = @())
    [pscustomobject][ordered]@{ question = $Question; target = $Target; state = $State; note = $Note; evidence = @($Evidence) }
}

function New-BlockedQueries {
    param([string]$State, [string]$Note)
    @(
        New-SmokeQuery "Where is MapTradeAutonomousService defined?" "MapTradeAutonomousService" $State $Note
        New-SmokeQuery "Where is StartRouteNow defined?" "StartRouteNow" $State $Note
        New-SmokeQuery "Who calls StartRouteNow?" "StartRouteNow references" $State $Note
        New-SmokeQuery "Where is CampaignMapReadyOrchestrator defined?" "CampaignMapReadyOrchestrator" $State $Note
        New-SmokeQuery "Where is _activeReport assigned, read, and cleared?" "MapTradeAutonomousService._activeReport references" $State $Note
        New-SmokeQuery "Where are hotkeys registered?" "DevHotkeyHandler / CommandSurfaceService" $State $Note
        New-SmokeQuery "Where is command inbox parsing handled?" "DevCommandFileInbox.TryParseInbox" $State $Note
    )
}

function Get-FilePosition {
    param([string]$Path, [string]$Pattern, [string]$Symbol)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $lines = Get-Content -LiteralPath $Path
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $Pattern) {
            $character = $lines[$i].IndexOf($Symbol, [System.StringComparison]::Ordinal)
            if ($character -lt 0) { $character = 0 }
            return [pscustomobject][ordered]@{ filePath = (Resolve-Path -LiteralPath $Path).Path; line = $i; character = $character; displayLine = $i + 1; text = $lines[$i].Trim() }
        }
    }
    return $null
}

function Send-McpJson { param([System.Diagnostics.Process]$Process, [object]$Message) $Process.StandardInput.WriteLine(($Message | ConvertTo-Json -Depth 50 -Compress)); $Process.StandardInput.Flush() }
function Receive-McpJson { param([System.Diagnostics.Process]$Process, [int]$TimeoutMilliseconds) $task = $Process.StandardOutput.ReadLineAsync(); if (-not $task.Wait($TimeoutMilliseconds)) { throw "Timed out waiting for MCP response after $TimeoutMilliseconds ms." }; if ([string]::IsNullOrWhiteSpace($task.Result)) { throw "MCP server closed stdout before returning a response." }; return $task.Result | ConvertFrom-Json }
function Invoke-McpRequest {
    param([System.Diagnostics.Process]$Process, [int]$Id, [string]$Method, [object]$Params, [int]$TimeoutMilliseconds)
    Send-McpJson -Process $Process -Message ([pscustomobject][ordered]@{ jsonrpc = "2.0"; id = $Id; method = $Method; params = $Params })
    while ($true) { $message = Receive-McpJson -Process $Process -TimeoutMilliseconds $TimeoutMilliseconds; if ($message.PSObject.Properties.Name -contains "id" -and [int]$message.id -eq $Id) { return $message } }
}
function Invoke-McpTool {
    param([System.Diagnostics.Process]$Process, [ref]$NextId, [string]$Name, [hashtable]$Arguments, [int]$TimeoutMilliseconds)
    $id = $NextId.Value; $NextId.Value = $NextId.Value + 1
    Invoke-McpRequest -Process $Process -Id $id -Method "tools/call" -Params ([pscustomobject][ordered]@{ name = $Name; arguments = $Arguments }) -TimeoutMilliseconds $TimeoutMilliseconds
}

function Get-McpContentText {
    param([object]$Response)
    if ($null -eq $Response -or -not ($Response.PSObject.Properties.Name -contains "result") -or $null -eq $Response.result.content) { return "" }
    (@($Response.result.content) | ForEach-Object { if ($_.PSObject.Properties.Name -contains "text") { [string]$_.text } }) -join "`n"
}

function Get-McpErrorText {
    param([object]$Response)
    if ($null -eq $Response -or -not ($Response.PSObject.Properties.Name -contains "error")) { return "" }
    $message = [string]$Response.error.message
    $code = [string]$Response.error.code
    $data = if ($Response.error.PSObject.Properties.Name -contains "data") { [string]$Response.error.data } else { "" }
    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($code)) { $parts += "code=$code" }
    if (-not [string]::IsNullOrWhiteSpace($message)) { $parts += "message=$message" }
    if (-not [string]::IsNullOrWhiteSpace($data)) { $parts += "data=$data" }
    $parts -join "; "
}

function Convert-ToolResponseToState {
    param([object]$Response)
    if ($null -eq $Response) { return "lsp_project_not_loaded" }
    $text = (Get-McpContentText -Response $Response)
    if ([string]::IsNullOrWhiteSpace($text)) { $text = Get-McpErrorText -Response $Response }
    if ($Response.PSObject.Properties.Name -contains "error") {
        if ($text -match "(?i)not found|no definition|no references|no symbols") { return "symbol_not_found" }
        return "lsp_project_not_loaded"
    }
    if ([string]::IsNullOrWhiteSpace($text)) { return "symbol_not_found" }
    if ($text -match "(?i)failed to start lsp|make sure csharp-ls is installed|project.*not.*load|workspace.*not.*set") { return "lsp_project_not_loaded" }
    if ($text -match "(?i)not found|no definition|no references|no symbols") { return "symbol_not_found" }
    return "symbol_navigation_ready"
}

function New-McpEvidence { param([string]$Tool, [object]$Response) $text = Get-McpContentText -Response $Response; if ([string]::IsNullOrWhiteSpace($text)) { $text = Get-McpErrorText -Response $Response }; if ($text.Length -gt 4000) { $text = $text.Substring(0, 4000) + "...[truncated]" }; [pscustomobject][ordered]@{ source = "mcp"; tool = $Tool; responseText = $text } }
function New-AnchorEvidence { param([object]$Anchor) [pscustomobject][ordered]@{ source = "repo-anchor"; file = $Anchor.filePath; line = $Anchor.displayLine; character = $Anchor.character; text = $Anchor.text } }

function Invoke-SymbolQuery {
    param([System.Diagnostics.Process]$Process, [ref]$NextId, [hashtable]$Spec, [int]$TimeoutMilliseconds)
    $anchor = Get-FilePosition -Path $Spec.File -Pattern $Spec.Pattern -Symbol $Spec.Symbol
    if ($null -eq $anchor) { return New-SmokeQuery $Spec.Question $Spec.Target "symbol_not_found" "Could not locate the source anchor needed to drive MCP/LSP navigation." }
    $arguments = @{ filePath = $anchor.filePath; content = (Get-Content -LiteralPath $anchor.filePath -Raw) }
    if ($Spec.Tool -eq "csharp_definition" -or $Spec.Tool -eq "csharp_references") { $arguments.line = $anchor.line; $arguments.character = $anchor.character }
    if ($Spec.Tool -eq "csharp_references") { $arguments.includeDeclaration = $true }
    $response = Invoke-McpTool -Process $Process -NextId $NextId -Name $Spec.Tool -Arguments $arguments -TimeoutMilliseconds $TimeoutMilliseconds
    $state = Convert-ToolResponseToState -Response $response
    $note = if ($state -eq "symbol_navigation_ready") { "MCP tool returned a non-empty navigation response." } elseif ($state -eq "lsp_project_not_loaded") { "MCP tool was reachable, but the C# LSP/project was not loaded." } else { "MCP tool ran, but did not return a usable symbol result." }
    New-SmokeQuery $Spec.Question $Spec.Target $state $note @((New-AnchorEvidence $anchor), (New-McpEvidence $Spec.Tool $response))
}

function Get-WorkspaceCandidates {
    param([string]$RepoRoot)
    $helper = Join-Path $RepoRoot "scripts/mcp/Get-TbgMcpWorkspaceCandidates.ps1"
    if (Test-Path -LiteralPath $helper) {
        try {
            $raw = & powershell -ExecutionPolicy Bypass -File $helper -RepoRoot $RepoRoot
            $parsed = $raw | ConvertFrom-Json
            foreach ($candidate in @($parsed)) { $candidate }
            return
        } catch { }
    }
    foreach ($candidate in @(
        [pscustomobject][ordered]@{ role = "csharp_project_directory"; path = (Join-Path $RepoRoot "src/BlacksmithGuild"); preferred = $true },
        [pscustomobject][ordered]@{ role = "repo_root_fallback"; path = $RepoRoot; preferred = $false }
    )) { $candidate }
}

function Write-SmokeResult { param([object]$Result) $artifactDir = Join-Path $Result.repoRoot "artifacts/latest"; New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null; $artifactPath = Join-Path $artifactDir "mcp-symbol-smoke.result.json"; $Result | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $artifactPath -Encoding UTF8; $Result | ConvertTo-Json -Depth 50 }

$repoRoot = Find-TbgRepoRoot
$timeoutMs = [Math]::Max(1, $TimeoutSeconds) * 1000
$artifactRelativePath = "artifacts/latest/mcp-symbol-smoke.result.json"
$branch = "unknown"
try { Push-Location $repoRoot; $branch = (& git rev-parse --abbrev-ref HEAD 2>$null).Trim() } finally { Pop-Location }
if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "unknown" }

$findings = New-Object System.Collections.Generic.List[string]
$missing = New-Object System.Collections.Generic.List[string]
$mcpTool = if ([string]::IsNullOrWhiteSpace($McpCommand)) { Resolve-TbgTool -RepoRoot $repoRoot -Names @("csharp-lsp-mcp", "csharp-lsp-mcp.exe") } else { $McpCommand }
$csharpLs = Resolve-TbgTool -RepoRoot $repoRoot -Names @("csharp-ls", "csharp-ls.exe")
if ([string]::IsNullOrWhiteSpace($mcpTool)) { $missing.Add("mcp_tool_missing:csharp-lsp-mcp") }
if ([string]::IsNullOrWhiteSpace($csharpLs)) { $missing.Add("lsp-tool-missing:csharp-ls") } else { $findings.Add("lsp-tool-ok:csharp-ls") }

$queries = @(); $mcpTools = @(); $workspaceResponseText = ""; $workspaceAttempts = @(); $selectedWorkspacePath = $null; $process = $null; $directLspResult = $null
if ($missing -contains "mcp_tool_missing:csharp-lsp-mcp") {
    $queries = New-BlockedQueries "mcp_tool_missing" "Missing MCP bridge command csharp-lsp-mcp."
} else {
    $findings.Add("mcp-tool-ok:csharp-lsp-mcp")
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $mcpTool; $startInfo.WorkingDirectory = $repoRoot; $startInfo.UseShellExecute = $false; $startInfo.RedirectStandardInput = $true; $startInfo.RedirectStandardOutput = $true; $startInfo.RedirectStandardError = $true; $startInfo.CreateNoWindow = $true
        foreach ($toolPath in @($mcpTool, $csharpLs)) { $dir = Split-Path -Parent $toolPath; if (-not [string]::IsNullOrWhiteSpace($dir)) { $startInfo.EnvironmentVariables["PATH"] = $dir + ";" + $startInfo.EnvironmentVariables["PATH"] } }
        $process = New-Object System.Diagnostics.Process; $process.StartInfo = $startInfo; [void]$process.Start()
        $nextId = 1
        [void](Invoke-McpRequest $process $nextId "initialize" ([pscustomobject][ordered]@{ protocolVersion = "2024-11-05"; capabilities = [pscustomobject]@{}; clientInfo = [pscustomobject][ordered]@{ name = "tbg-mcp-symbol-smoke"; version = "0.2" } }) $timeoutMs); $nextId++
        Send-McpJson $process ([pscustomobject][ordered]@{ jsonrpc = "2.0"; method = "notifications/initialized"; params = [pscustomobject]@{} })
        $toolsResponse = Invoke-McpRequest $process $nextId "tools/list" ([pscustomobject]@{}) $timeoutMs; $nextId++
        if ($toolsResponse.result.tools) { $mcpTools = @($toolsResponse.result.tools | ForEach-Object { $_.name }) }
        foreach ($requiredTool in @("csharp_set_workspace", "csharp_definition", "csharp_references", "csharp_symbols")) { if ($mcpTools -contains $requiredTool) { $findings.Add("mcp-tool-listed:$requiredTool") } else { $missing.Add("mcp-tool-missing:$requiredTool") } }
        if ($missing | Where-Object { $_ -match "^mcp-tool-missing:" }) { $queries = New-BlockedQueries "mcp_tool_missing" "The MCP bridge did not expose all required C# symbol tools." }
        else {
            foreach ($workspace in @(Get-WorkspaceCandidates $repoRoot)) {
                $workspacePath = [string]$workspace.path
                if ([string]::IsNullOrWhiteSpace($workspacePath) -or -not (Test-Path -LiteralPath $workspacePath -PathType Container)) { continue }
                $workspaceResponse = $null
                $attemptText = ""
                $workspaceHasError = $true
                try {
                    $workspaceResponse = Invoke-McpTool -Process $process -NextId ([ref]$nextId) -Name "csharp_set_workspace" -Arguments @{ path = $workspacePath } -TimeoutMilliseconds $timeoutMs
                    $attemptText = Get-McpContentText $workspaceResponse
                    if ([string]::IsNullOrWhiteSpace($attemptText)) { $attemptText = Get-McpErrorText $workspaceResponse }
                    $workspaceHasError = ($workspaceResponse.PSObject.Properties.Name -contains "error") -or ($attemptText -match "(?i)^error:|failed|does not exist|project.*not.*load|workspace.*not.*set")
                } catch {
                    $attemptText = $_.Exception.Message
                    $workspaceHasError = $true
                }
                $workspaceAttempts += [pscustomobject][ordered]@{ path = $workspacePath; role = $workspace.role; hasError = $workspaceHasError; responseText = $attemptText }
                if (-not $workspaceHasError) { $selectedWorkspacePath = $workspacePath; $workspaceResponseText = $attemptText; break }
                if ([string]::IsNullOrWhiteSpace($workspaceResponseText)) { $workspaceResponseText = $attemptText }
            }
            if ([string]::IsNullOrWhiteSpace($selectedWorkspacePath)) { $queries = New-BlockedQueries "lsp_project_not_loaded" "csharp_set_workspace failed for all workspace candidates." }
            else {
                $specs = @(
                    @{ Question="Where is MapTradeAutonomousService defined?"; Target="MapTradeAutonomousService"; Tool="csharp_definition"; File=(Join-Path $repoRoot "src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs"); Pattern="\bclass\s+MapTradeAutonomousService\b"; Symbol="MapTradeAutonomousService" },
                    @{ Question="Where is StartRouteNow defined?"; Target="StartRouteNow"; Tool="csharp_definition"; File=(Join-Path $repoRoot "src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs"); Pattern="\bStartRouteNow\b"; Symbol="StartRouteNow" },
                    @{ Question="Who calls StartRouteNow?"; Target="StartRouteNow references"; Tool="csharp_references"; File=(Join-Path $repoRoot "src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs"); Pattern="\bStartRouteNow\b"; Symbol="StartRouteNow" },
                    @{ Question="Where is CampaignMapReadyOrchestrator defined?"; Target="CampaignMapReadyOrchestrator"; Tool="csharp_definition"; File=(Join-Path $repoRoot "src/BlacksmithGuild/DevTools/CampaignMapReadyOrchestrator.cs"); Pattern="\bclass\s+CampaignMapReadyOrchestrator\b"; Symbol="CampaignMapReadyOrchestrator" },
                    @{ Question="Where is _activeReport assigned, read, and cleared?"; Target="MapTradeAutonomousService._activeReport references"; Tool="csharp_references"; File=(Join-Path $repoRoot "src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs"); Pattern="MapTradeCertReport\s+_activeReport\b"; Symbol="_activeReport" },
                    @{ Question="Where are hotkeys registered?"; Target="DevHotkeyHandler.PollHotkeys"; Tool="csharp_symbols"; File=(Join-Path $repoRoot "src/BlacksmithGuild/DevTools/DevHotkeyHandler.cs"); Pattern="PollHotkeys\(\)"; Symbol="PollHotkeys" },
                    @{ Question="Where is command inbox parsing handled?"; Target="DevCommandFileInbox.TryParseInbox"; Tool="csharp_definition"; File=(Join-Path $repoRoot "src/BlacksmithGuild/DevTools/DevCommandFileInbox.cs"); Pattern="TryParseInbox\("; Symbol="TryParseInbox" }
                )
                foreach ($spec in $specs) { $queries += Invoke-SymbolQuery $process ([ref]$nextId) $spec $timeoutMs }
            }
        }
    } catch { $missing.Add("lsp_project_not_loaded:" + $_.Exception.Message); $queries = New-BlockedQueries "lsp_project_not_loaded" $_.Exception.Message }
    finally { if ($null -ne $process -and -not $process.HasExited) { try { $process.Kill() } catch { } } }
}

$directLspHelper = Join-Path $repoRoot "scripts/mcp/Invoke-TbgCsharpLsSymbolSmoke.js"
$canTryDirectLsp = (-not [string]::IsNullOrWhiteSpace($mcpTool)) -and (-not [string]::IsNullOrWhiteSpace($csharpLs)) -and (Test-Path -LiteralPath $directLspHelper) -and ($null -ne (Get-Command node -ErrorAction SilentlyContinue))
if ($canTryDirectLsp -and ([string]::IsNullOrWhiteSpace($selectedWorkspacePath)) -and -not ($queries | Where-Object { $_.state -eq "mcp_tool_missing" })) {
    try {
        $directRaw = & node $directLspHelper --repoRoot $repoRoot --timeoutSeconds $TimeoutSeconds --csharpLs $csharpLs
        $directLspResult = $directRaw | ConvertFrom-Json
        $findings.Add("lsp-direct-fallback:$($directLspResult.verdict)")
        if ($directLspResult.workspacePath) { $selectedWorkspacePath = [string]$directLspResult.workspacePath }
        if ($directLspResult.queries) { $queries = @($directLspResult.queries) }
    } catch {
        $missing.Add("lsp-direct-fallback-failed:" + $_.Exception.Message)
    }
}

$states = @($queries | ForEach-Object { $_.state })
$verdict = "symbol_navigation_ready"; $status = "ready"
if ($states -contains "mcp_tool_missing") { $verdict = "mcp_tool_missing"; $status = "missing_prereqs" }
elseif ($states -contains "lsp_project_not_loaded") { $verdict = "lsp_project_not_loaded"; $status = "missing_prereqs" }
elseif ($states -contains "symbol_not_found") { $verdict = "symbol_not_found"; $status = "missing_prereqs" }

Write-SmokeResult ([pscustomobject][ordered]@{
    schema = "tbg.harness.result.v1"; action = "TestMcpSymbolSmoke"; timestampUtc = (Get-Date).ToUniversalTime().ToString("o"); repoRoot = $repoRoot; branch = $branch; contractId = $ContractId; status = $status; verdict = $verdict; findings = @($findings); missingPrereqs = @($missing); forbiddenScopeTouched = $false; artifacts = @($artifactRelativePath);
    workspace = [pscustomobject][ordered]@{ selectedPath = $selectedWorkspacePath; attempts = @($workspaceAttempts) }
    tools = [pscustomobject][ordered]@{ mcpCommand = $mcpTool; csharpLs = $csharpLs; mcpTools = @($mcpTools); workspaceResponse = $workspaceResponseText; directLsp = $directLspResult }
    queries = @($queries)
})
