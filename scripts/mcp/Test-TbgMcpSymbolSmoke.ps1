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
    param(
        [string]$RepoRoot,
        [string[]]$Names
    )

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
    param(
        [string]$Question,
        [string]$Target,
        [string]$State,
        [string]$Note,
        [object[]]$Evidence = @(),
        [object[]]$Locations = @()
    )

    return [pscustomobject][ordered]@{
        question = $Question
        target = $Target
        state = $State
        note = $Note
        locations = @($Locations)
        evidence = @($Evidence)
    }
}

function New-BlockedQueries {
    param(
        [string]$State,
        [string]$Note
    )

    $questions = @(
        @("Where is MapTradeAutonomousService defined?", "MapTradeAutonomousService"),
        @("Where is StartRouteNow defined?", "StartRouteNow"),
        @("Who calls StartRouteNow?", "StartRouteNow references"),
        @("Where is CampaignMapReadyOrchestrator defined?", "CampaignMapReadyOrchestrator"),
        @("Where is _activeReport assigned, read, and cleared?", "MapTradeAutonomousService._activeReport references"),
        @("Where are hotkeys registered?", "DevHotkeyHandler / CommandSurfaceService"),
        @("Where is command inbox parsing handled?", "DevCommandFileInbox.TryParseInbox")
    )

    foreach ($question in $questions) {
        New-SmokeQuery -Question $question[0] -Target $question[1] -State $State -Note $Note
    }
}

function Get-FilePosition {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Symbol
    )

    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    $lines = Get-Content -LiteralPath $Path
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $Pattern) {
            $character = $lines[$i].IndexOf($Symbol, [System.StringComparison]::Ordinal)
            if ($character -lt 0) { $character = 0 }
            return [pscustomobject][ordered]@{
                filePath = (Resolve-Path -LiteralPath $Path).Path
                line = $i
                character = $character
                displayLine = $i + 1
                text = $lines[$i].Trim()
            }
        }
    }

    return $null
}

function Send-McpJson {
    param(
        [System.Diagnostics.Process]$Process,
        [object]$Message
    )

    $json = $Message | ConvertTo-Json -Depth 50 -Compress
    $Process.StandardInput.WriteLine($json)
    $Process.StandardInput.Flush()
}

function Receive-McpJson {
    param(
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutMilliseconds
    )

    $task = $Process.StandardOutput.ReadLineAsync()
    if (-not $task.Wait($TimeoutMilliseconds)) {
        throw "Timed out waiting for MCP response after $TimeoutMilliseconds ms."
    }

    $line = $task.Result
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "MCP server closed stdout before returning a response."
    }

    return $line | ConvertFrom-Json
}

function Invoke-McpRequest {
    param(
        [System.Diagnostics.Process]$Process,
        [int]$Id,
        [string]$Method,
        [object]$Params,
        [int]$TimeoutMilliseconds
    )

    Send-McpJson -Process $Process -Message ([pscustomobject][ordered]@{
        jsonrpc = "2.0"
        id = $Id
        method = $Method
        params = $Params
    })

    while ($true) {
        $message = Receive-McpJson -Process $Process -TimeoutMilliseconds $TimeoutMilliseconds
        if ($message.PSObject.Properties.Name -contains "id" -and [int]$message.id -eq $Id) {
            return $message
        }
    }
}

function Invoke-McpTool {
    param(
        [System.Diagnostics.Process]$Process,
        [ref]$NextId,
        [string]$Name,
        [hashtable]$Arguments,
        [int]$TimeoutMilliseconds
    )

    $id = $NextId.Value
    $NextId.Value = $NextId.Value + 1
    return Invoke-McpRequest -Process $Process -Id $id -Method "tools/call" -Params ([pscustomobject][ordered]@{
        name = $Name
        arguments = $Arguments
    }) -TimeoutMilliseconds $TimeoutMilliseconds
}

function Get-McpContentText {
    param([object]$Response)

    if ($null -eq $Response -or -not ($Response.PSObject.Properties.Name -contains "result")) { return "" }
    if ($null -eq $Response.result.content) { return "" }

    $parts = @()
    foreach ($item in @($Response.result.content)) {
        if ($item.PSObject.Properties.Name -contains "text") { $parts += [string]$item.text }
    }

    return ($parts -join "`n").Trim()
}

function New-AnchorEvidence {
    param([object]$Anchor)

    return [pscustomobject][ordered]@{
        source = "repo-anchor"
        file = $Anchor.filePath
        line = $Anchor.displayLine
        character = $Anchor.character
        text = $Anchor.text
    }
}

function New-McpEvidence {
    param(
        [string]$Tool,
        [object]$Response
    )

    $text = Get-McpContentText -Response $Response
    if ($text.Length -gt 4000) { $text = $text.Substring(0, 4000) + "...[truncated]" }

    return [pscustomobject][ordered]@{
        source = "mcp"
        tool = $Tool
        responseText = $text
    }
}

function Convert-ToolResponseToState {
    param([object]$Response)

    if ($Response.PSObject.Properties.Name -contains "error") { return "symbol_not_found" }

    $text = Get-McpContentText -Response $Response
    if ([string]::IsNullOrWhiteSpace($text)) { return "symbol_not_found" }
    if ($text -match "(?i)failed to start lsp|make sure csharp-ls is installed|project.*not.*load|workspace.*not.*set") {
        return "lsp_project_not_loaded"
    }
    if ($text -match "(?i)not found|no definition|no references|no symbols") { return "symbol_not_found" }

    return "symbol_navigation_ready"
}

function Invoke-SymbolQuery {
    param(
        [System.Diagnostics.Process]$Process,
        [ref]$NextId,
        [hashtable]$Spec,
        [int]$TimeoutMilliseconds
    )

    $anchor = Get-FilePosition -Path $Spec.File -Pattern $Spec.Pattern -Symbol $Spec.Symbol
    if ($null -eq $anchor) {
        return New-SmokeQuery -Question $Spec.Question -Target $Spec.Target -State "symbol_not_found" -Note "Could not locate the source anchor needed to drive MCP/LSP navigation."
    }

    $content = Get-Content -LiteralPath $anchor.filePath -Raw
    $arguments = @{
        filePath = $anchor.filePath
        content = $content
    }

    if ($Spec.Tool -eq "csharp_definition" -or $Spec.Tool -eq "csharp_references") {
        $arguments.line = $anchor.line
        $arguments.character = $anchor.character
    }
    if ($Spec.Tool -eq "csharp_references") {
        $arguments.includeDeclaration = $true
    }

    $response = Invoke-McpTool -Process $Process -NextId $NextId -Name $Spec.Tool -Arguments $arguments -TimeoutMilliseconds $TimeoutMilliseconds
    $state = Convert-ToolResponseToState -Response $response
    $note = if ($state -eq "symbol_navigation_ready") {
        "MCP tool returned a non-empty navigation response."
    } elseif ($state -eq "lsp_project_not_loaded") {
        "MCP tool was reachable, but the C# LSP/project was not loaded."
    } else {
        "MCP tool ran, but did not return a usable symbol result."
    }

    New-SmokeQuery `
        -Question $Spec.Question `
        -Target $Spec.Target `
        -State $state `
        -Note $note `
        -Evidence @((New-AnchorEvidence -Anchor $anchor), (New-McpEvidence -Tool $Spec.Tool -Response $response))
}

function Write-SmokeResult {
    param([object]$Result)

    $artifactDir = Join-Path $Result.repoRoot "artifacts/latest"
    New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
    $artifactPath = Join-Path $artifactDir "mcp-symbol-smoke.result.json"
    $Result | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $artifactPath -Encoding UTF8
    $Result | ConvertTo-Json -Depth 50
}

$repoRoot = Find-TbgRepoRoot
$timeoutMs = [Math]::Max(1, $TimeoutSeconds) * 1000
$artifactRelativePath = "artifacts/latest/mcp-symbol-smoke.result.json"

$branch = "unknown"
try {
    Push-Location $repoRoot
    $branch = (& git rev-parse --abbrev-ref HEAD 2>$null).Trim()
} finally {
    Pop-Location
}
if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "unknown" }

$findings = New-Object System.Collections.Generic.List[string]
$missing = New-Object System.Collections.Generic.List[string]

$mcpTool = $McpCommand
if ([string]::IsNullOrWhiteSpace($mcpTool)) {
    $mcpTool = Resolve-TbgTool -RepoRoot $repoRoot -Names @("csharp-lsp-mcp", "csharp-lsp-mcp.exe")
}

$csharpLs = Resolve-TbgTool -RepoRoot $repoRoot -Names @("csharp-ls", "csharp-ls.exe")

if ([string]::IsNullOrWhiteSpace($mcpTool)) {
    $missing.Add("mcp_tool_missing:csharp-lsp-mcp")
    $queries = New-BlockedQueries -State "mcp_tool_missing" -Note "Missing MCP bridge command csharp-lsp-mcp."
    Write-SmokeResult -Result ([pscustomobject][ordered]@{
        schema = "tbg.harness.result.v1"
        action = "TestMcpSymbolSmoke"
        timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
        repoRoot = $repoRoot
        branch = $branch
        contractId = $ContractId
        status = "missing_prereqs"
        verdict = "mcp_tool_missing"
        findings = @($findings)
        missingPrereqs = @($missing)
        forbiddenScopeTouched = $false
        artifacts = @($artifactRelativePath)
        tools = [pscustomobject][ordered]@{
            mcpCommand = $null
            csharpLs = $csharpLs
        }
        queries = @($queries)
    })
    exit 0
}

$findings.Add("mcp-tool-ok:csharp-lsp-mcp")
if ([string]::IsNullOrWhiteSpace($csharpLs)) {
    $missing.Add("lsp-tool-missing:csharp-ls")
} else {
    $findings.Add("lsp-tool-ok:csharp-ls")
}

$process = $null
$queries = @()
$mcpTools = @()
$workspaceResponseText = ""

try {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $mcpTool
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $toolDir = Split-Path -Parent $mcpTool
    if (-not [string]::IsNullOrWhiteSpace($toolDir)) {
        $startInfo.EnvironmentVariables["PATH"] = $toolDir + ";" + $startInfo.EnvironmentVariables["PATH"]
    }

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()

    $nextId = 1
    [void](Invoke-McpRequest -Process $process -Id $nextId -Method "initialize" -Params ([pscustomobject][ordered]@{
        protocolVersion = "2024-11-05"
        capabilities = [pscustomobject]@{}
        clientInfo = [pscustomobject][ordered]@{
            name = "tbg-mcp-symbol-smoke"
            version = "0.1"
        }
    }) -TimeoutMilliseconds $timeoutMs)
    $nextId++

    Send-McpJson -Process $process -Message ([pscustomobject][ordered]@{
        jsonrpc = "2.0"
        method = "notifications/initialized"
        params = [pscustomobject]@{}
    })

    $toolsResponse = Invoke-McpRequest -Process $process -Id $nextId -Method "tools/list" -Params ([pscustomobject]@{}) -TimeoutMilliseconds $timeoutMs
    $nextId++

    if ($toolsResponse.result.tools) {
        $mcpTools = @($toolsResponse.result.tools | ForEach-Object { $_.name })
        foreach ($requiredTool in @("csharp_set_workspace", "csharp_definition", "csharp_references", "csharp_symbols")) {
            if ($mcpTools -contains $requiredTool) {
                $findings.Add("mcp-tool-listed:$requiredTool")
            } else {
                $missing.Add("mcp-tool-missing:$requiredTool")
            }
        }
    } else {
        $missing.Add("mcp_tool_missing:tools/list-empty")
    }

    if ($missing | Where-Object { $_ -match "^mcp-tool-missing:" }) {
        $queries = New-BlockedQueries -State "mcp_tool_missing" -Note "The MCP bridge did not expose all required C# symbol tools."
    } else {
        $workspaceResponse = Invoke-McpTool -Process $process -NextId ([ref]$nextId) -Name "csharp_set_workspace" -Arguments @{ path = $repoRoot } -TimeoutMilliseconds $timeoutMs
        $workspaceResponseText = Get-McpContentText -Response $workspaceResponse

        if ((Convert-ToolResponseToState -Response $workspaceResponse) -eq "lsp_project_not_loaded") {
            $queries = New-BlockedQueries -State "lsp_project_not_loaded" -Note $workspaceResponseText
        } else {
            $specs = @(
                @{
                    Question = "Where is MapTradeAutonomousService defined?"
                    Target = "MapTradeAutonomousService"
                    Tool = "csharp_definition"
                    File = Join-Path $repoRoot "src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs"
                    Pattern = "\bclass\s+MapTradeAutonomousService\b"
                    Symbol = "MapTradeAutonomousService"
                },
                @{
                    Question = "Where is StartRouteNow defined?"
                    Target = "StartRouteNow"
                    Tool = "csharp_definition"
                    File = Join-Path $repoRoot "src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs"
                    Pattern = "\bStartRouteNow\b"
                    Symbol = "StartRouteNow"
                },
                @{
                    Question = "Who calls StartRouteNow?"
                    Target = "StartRouteNow references"
                    Tool = "csharp_references"
                    File = Join-Path $repoRoot "src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs"
                    Pattern = "\bStartRouteNow\b"
                    Symbol = "StartRouteNow"
                },
                @{
                    Question = "Where is CampaignMapReadyOrchestrator defined?"
                    Target = "CampaignMapReadyOrchestrator"
                    Tool = "csharp_definition"
                    File = Join-Path $repoRoot "src/BlacksmithGuild/DevTools/CampaignMapReadyOrchestrator.cs"
                    Pattern = "\bclass\s+CampaignMapReadyOrchestrator\b"
                    Symbol = "CampaignMapReadyOrchestrator"
                },
                @{
                    Question = "Where is _activeReport assigned, read, and cleared?"
                    Target = "MapTradeAutonomousService._activeReport references"
                    Tool = "csharp_references"
                    File = Join-Path $repoRoot "src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs"
                    Pattern = "MapTradeCertReport\s+_activeReport\b"
                    Symbol = "_activeReport"
                },
                @{
                    Question = "Where are hotkeys registered?"
                    Target = "DevHotkeyHandler.PollHotkeys"
                    Tool = "csharp_symbols"
                    File = Join-Path $repoRoot "src/BlacksmithGuild/DevTools/DevHotkeyHandler.cs"
                    Pattern = "PollHotkeys\(\)"
                    Symbol = "PollHotkeys"
                },
                @{
                    Question = "Where is command inbox parsing handled?"
                    Target = "DevCommandFileInbox.TryParseInbox"
                    Tool = "csharp_definition"
                    File = Join-Path $repoRoot "src/BlacksmithGuild/DevTools/DevCommandFileInbox.cs"
                    Pattern = "TryParseInbox\("
                    Symbol = "TryParseInbox"
                }
            )

            foreach ($spec in $specs) {
                $queries += Invoke-SymbolQuery -Process $process -NextId ([ref]$nextId) -Spec $spec -TimeoutMilliseconds $timeoutMs
            }
        }
    }
} catch {
    $missing.Add("lsp_project_not_loaded:" + $_.Exception.Message)
    $queries = New-BlockedQueries -State "lsp_project_not_loaded" -Note $_.Exception.Message
} finally {
    if ($null -ne $process -and -not $process.HasExited) {
        try { $process.Kill() } catch { }
    }
}

$states = @($queries | ForEach-Object { $_.state })
$verdict = "symbol_navigation_ready"
$status = "ready"
if ($states -contains "mcp_tool_missing") {
    $verdict = "mcp_tool_missing"
    $status = "missing_prereqs"
} elseif ($states -contains "lsp_project_not_loaded") {
    $verdict = "lsp_project_not_loaded"
    $status = "missing_prereqs"
} elseif ($states -contains "symbol_not_found") {
    $verdict = "symbol_not_found"
    $status = "missing_prereqs"
}

Write-SmokeResult -Result ([pscustomobject][ordered]@{
    schema = "tbg.harness.result.v1"
    action = "TestMcpSymbolSmoke"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    repoRoot = $repoRoot
    branch = $branch
    contractId = $ContractId
    status = $status
    verdict = $verdict
    findings = @($findings)
    missingPrereqs = @($missing)
    forbiddenScopeTouched = $false
    artifacts = @($artifactRelativePath)
    tools = [pscustomobject][ordered]@{
        mcpCommand = $mcpTool
        csharpLs = $csharpLs
        mcpTools = @($mcpTools)
        workspaceResponse = $workspaceResponseText
    }
    queries = @($queries)
})
