[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [string]$ProfilePath = (Join-Path $PSScriptRoot '..\config\l850-profile.json')
)

$ErrorActionPreference = 'Stop'
$profile = Get-Content -LiteralPath $ProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $WorkspaceRoot) { $WorkspaceRoot = $profile.workspace.offlineRoot }
$packagePath = [string]$profile.argus.defaultPath
New-Item -ItemType Directory -Force -Path $WorkspaceRoot | Out-Null

$packageExists = Test-Path -LiteralPath $packagePath
$entrypoints = @()
if ($packageExists) {
    $patterns = @('pyproject.toml','requirements.txt','README*','*server*.py','main.py','*.exe','*.cmd','*.bat')
    foreach ($pat in $patterns) {
        $entrypoints += @(Get-ChildItem -LiteralPath $packagePath -Filter $pat -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 20 -ExpandProperty FullName)
    }
    $entrypoints = @($entrypoints | Select-Object -Unique | Select-Object -First 40)
}

$processRows = @()
try {
    $processRows = @(Get-CimInstance Win32_Process -ErrorAction Stop | Select-Object ProcessId,Name,ExecutablePath,CommandLine)
} catch {
    $processRows = @()
}

$argusProcesses = @($processRows | Where-Object {
    ($_.CommandLine -and ($_.CommandLine -match '(?i)argus|argus_mcp_reverse-skill')) -or
    ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($packagePath,[System.StringComparison]::OrdinalIgnoreCase))
})

$targetProcesses = @($processRows | Where-Object {
    $_.Name -match '(?i)^(TW13081901(?:\.BIN)?|Lin(?:\.bin2)?|Lineage.*)\.?(exe|bin)?$' -or
    ($_.ExecutablePath -and $_.ExecutablePath -match '(?i)8\.50c|客服端|TW13081901|Lin\.bin2')
})

$packageStatus = if ($packageExists) { 'PRESENT' } else { 'MISSING' }
$serverStatus = if ($argusProcesses.Count -gt 0) { 'PROCESS_DETECTED' } elseif ($packageExists) { 'NOT_DETECTED' } else { 'PACKAGE_MISSING' }
$targetStatus = if ($targetProcesses.Count -gt 0) { 'TARGET_DETECTED' } else { 'NO_TARGET_PROCESS' }

$result = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    argus_package_path = $packagePath
    argus_package_status = $packageStatus
    argus_entrypoints = $entrypoints
    argus_server_process_status = $serverStatus
    argus_processes = @($argusProcesses)
    target_process_status = $targetStatus
    target_processes = @($targetProcesses)
    memory_write = $false
    packet_send = $false
    game_action = $false
}

$outPath = Join-Path $WorkspaceRoot 'l850-argus-status.json'
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outPath -Encoding UTF8

Write-Output "ARGUS_PACKAGE_STATUS=$packageStatus"
Write-Output "ARGUS_SERVER_PROCESS_STATUS=$serverStatus"
Write-Output "ARGUS_TARGET_STATUS=$targetStatus"
if ($targetProcesses.Count -gt 0) {
    foreach ($p in $targetProcesses) {
        Write-Output ("ARGUS_TARGET_PROCESS={0};PID={1}" -f $p.Name,$p.ProcessId)
    }
}
Write-Output "ARGUS_STATUS_FILE=$outPath"
if (-not $packageExists) {
    Write-Output 'ARGUS_MCP_STATUS=BLOCKED_ARGUS_PACKAGE_UNAVAILABLE'
} elseif ($targetProcesses.Count -eq 0) {
    Write-Output 'ARGUS_MCP_STATUS=BLOCKED_NO_TARGET_PROCESS'
} elseif ($argusProcesses.Count -eq 0) {
    Write-Output 'ARGUS_MCP_STATUS=PACKAGE_READY_SERVER_NOT_DETECTED_TARGET_PRESENT'
} else {
    Write-Output 'ARGUS_MCP_STATUS=PACKAGE_AND_PROCESS_DETECTED'
}
