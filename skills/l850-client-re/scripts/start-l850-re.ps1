[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [switch]$SkipHashValidation
)

$ErrorActionPreference = 'Stop'

$skillRoot = Split-Path -Parent $PSScriptRoot
$profilePath = Join-Path $skillRoot 'config\l850-profile.json'
$initScript = Join-Path $PSScriptRoot 'init-l850-case.ps1'
$toolDiscovery = Join-Path $skillRoot '..\scripts\lib\ToolDiscovery.ps1'

if (-not (Test-Path -LiteralPath $profilePath)) { throw "Missing L850 profile: $profilePath" }
if (-not (Test-Path -LiteralPath $toolDiscovery)) { throw "Missing ToolDiscovery: $toolDiscovery" }

. $toolDiscovery
$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json

if (-not $WorkspaceRoot) { $WorkspaceRoot = $profile.workspace.offlineRoot }

if (-not $SkipHashValidation) {
    & $initScript -WorkspaceRoot $WorkspaceRoot
    if ($LASTEXITCODE -ne 0) { throw "L850 case initialization failed." }
}

$ghidra = Resolve-ReverseToolSpec -Name 'analyzeHeadless'
$python = Resolve-ReverseToolSpec -Name 'python'
$argus = Resolve-ReverseToolSpec -Name 'argus-mcp'
$argusStatusScript = Join-Path $PSScriptRoot 'check-argus-status.ps1'
$argusRuntimeStatus = 'UNKNOWN'
$argusServerStatus = 'UNKNOWN'
$argusTargetStatus = 'UNKNOWN'
if (Test-Path -LiteralPath $argusStatusScript) {
    try {
        $null = & $argusStatusScript -WorkspaceRoot $WorkspaceRoot
        $argusStatusPath = Join-Path $WorkspaceRoot 'l850-argus-status.json'
        if (Test-Path -LiteralPath $argusStatusPath) {
            $argusState = Get-Content -LiteralPath $argusStatusPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $argusServerStatus = [string]$argusState.argus_server_process_status
            $argusTargetStatus = [string]$argusState.target_process_status
            if (-not $argus.Available) {
                $argusRuntimeStatus = 'BLOCKED_ARGUS_PACKAGE_UNAVAILABLE'
            } elseif ($argusTargetStatus -eq 'NO_TARGET_PROCESS') {
                $argusRuntimeStatus = 'BLOCKED_NO_TARGET_PROCESS'
            } elseif ($argusServerStatus -eq 'PROCESS_DETECTED') {
                $argusRuntimeStatus = 'PACKAGE_AND_PROCESS_DETECTED'
            } else {
                $argusRuntimeStatus = 'PACKAGE_READY_SERVER_NOT_DETECTED_TARGET_PRESENT'
            }
        }
    } catch {
        $argusRuntimeStatus = 'STATUS_PROBE_FAILED'
    }
}

$capstoneAvailable = $false
$capstoneVersion = $null
if ($python.Available -and $python.ResolvedPath) {
    try {
        $output = & $python.ResolvedPath -c "import capstone; print(capstone.__version__)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $output) {
            $capstoneAvailable = $true
            $capstoneVersion = ($output | Select-Object -First 1).Trim()
        }
    }
    catch {
        $capstoneAvailable = $false
    }
}

$toolAudit = [ordered]@{
    project = 'L850'
    generated_at = (Get-Date).ToString('o')
    workspace = $WorkspaceRoot
    ghidra_required = $true
    ghidra_available = [bool]$ghidra.Available
    ghidra_path = $ghidra.ResolvedPath
    capstone_required = $true
    capstone_available = $capstoneAvailable
    capstone_version = $capstoneVersion
    python_path = $python.ResolvedPath
    argus_required_for_runtime_blockers = $true
    argus_package_available = [bool]$argus.Available
    argus_path = $argus.ResolvedPath
    argus_runtime_status = $argusRuntimeStatus
    argus_server_process_status = $argusServerStatus
    argus_target_process_status = $argusTargetStatus
    whole_image_analysis = $false
    memory_write = $false
    packet_send = $false
    game_action = $false
}

New-Item -ItemType Directory -Force -Path $WorkspaceRoot | Out-Null
$auditPath = Join-Path $WorkspaceRoot 'l850-tool-audit.json'
$toolAudit | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $auditPath -Encoding UTF8

if (-not $ghidra.Available) {
    Write-Output 'GHIDRA_STATUS=BLOCKED_GHIDRA_UNAVAILABLE'
}
else {
    Write-Output "GHIDRA_STATUS=READY"
    Write-Output "GHIDRA_PATH=$($ghidra.ResolvedPath)"
}

if (-not $capstoneAvailable) {
    Write-Output 'CAPSTONE_STATUS=BLOCKED_CAPSTONE_UNAVAILABLE'
}
else {
    Write-Output "CAPSTONE_STATUS=READY"
    Write-Output "CAPSTONE_VERSION=$capstoneVersion"
}

if (-not $argus.Available) {
    Write-Output 'ARGUS_MCP_STATUS=BLOCKED_ARGUS_PACKAGE_UNAVAILABLE'
}
else {
    Write-Output "ARGUS_MCP_STATUS=$argusRuntimeStatus"
    Write-Output "ARGUS_MCP_PATH=$($argus.ResolvedPath)"
    Write-Output "ARGUS_SERVER_PROCESS_STATUS=$argusServerStatus"
    Write-Output "ARGUS_TARGET_STATUS=$argusTargetStatus"
}

Write-Output "TOOL_AUDIT=$auditPath"

if (-not $ghidra.Available -or -not $capstoneAvailable) {
    Write-Output 'STATUS=BLOCKED_REQUIRED_STATIC_TOOL'
    exit 2
}

Write-Output 'STATUS=READY_FOR_L850_RE'
Write-Output 'NEXT=Run bounded Ghidra discovery and hash-pinned focused Capstone proof on the highest-priority unresolved item.'
