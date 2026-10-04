[CmdletBinding()]
param(
    [string]$TargetRoot = 'I:\Lineage-tools\argus_mcp_reverse-skill',
    [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'

if (-not $SourceRoot) {
    $SourceRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
}

$sourceSkills = Join-Path $SourceRoot 'skills'
if (-not (Test-Path -LiteralPath $sourceSkills)) {
    throw "reverse-skill skills directory not found: $sourceSkills"
}
if (-not (Test-Path -LiteralPath $TargetRoot)) {
    New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$targetSkills = Join-Path $TargetRoot 'skills'
if (Test-Path -LiteralPath $targetSkills) {
    $backup = Join-Path $TargetRoot ("skills.backup-before-safe-l850-" + $stamp)
    Move-Item -LiteralPath $targetSkills -Destination $backup
    Write-Output "SKILLS_BACKUP=$backup"
}
New-Item -ItemType Directory -Force -Path $targetSkills | Out-Null

$dirMap = @(
    @{ Source = 'l850-client-re'; Destination = 'l850-client-re' }
)
$fileMap = @(
    @{ Source = 'MASTER-ROUTING.md'; Destination = 'MASTER-ROUTING.md' },
    @{ Source = 'SKILL.md'; Destination = 'SKILL.md' },
    @{ Source = 'INDEX.md'; Destination = 'INDEX.md' },
    @{ Source = 'routing.md'; Destination = 'routing.md' },
    @{ Source = 'config\routing.json'; Destination = 'config\routing.json' },
    @{ Source = 'scripts\master-route.ps1'; Destination = 'scripts\master-route.ps1' },
    @{ Source = 'scripts\lib\WorkRoot.ps1'; Destination = 'scripts\lib\WorkRoot.ps1' },
    @{ Source = 'scripts\lib\ToolDiscovery.ps1'; Destination = 'scripts\lib\ToolDiscovery.ps1' }
)

foreach ($entry in $dirMap) {
    $src = Join-Path $sourceSkills $entry.Source
    $dst = Join-Path $targetSkills $entry.Destination
    if (-not (Test-Path -LiteralPath $src)) { throw "Missing required source directory: $src" }
    Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
}

foreach ($entry in $fileMap) {
    $src = Join-Path $sourceSkills $entry.Source
    $dst = Join-Path $targetSkills $entry.Destination
    if (-not (Test-Path -LiteralPath $src)) { throw "Missing required source file: $src" }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
}

$marker = [ordered]@{
    installed_at = (Get-Date).ToString('o')
    source_root = $SourceRoot
    target_root = $TargetRoot
    layout = 'integrated-argus-root-safe-subset-local'
    excluded = @('pentest-tools','malware-analysis','attack-chain','pwn-chain','edr-bypass-re','patch-diff-exploit')
    l850_skill = 'skills\l850-client-re\SKILL.md'
    argus_root = $TargetRoot
}
$markerPath = Join-Path $TargetRoot 'L850_REVERSE_SKILL_INSTALL.json'
$marker | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $markerPath -Encoding UTF8

Write-Output 'STATUS=PASS'
Write-Output "TARGET_ROOT=$TargetRoot"
Write-Output "L850_SKILL=$(Join-Path $TargetRoot 'skills\l850-client-re\SKILL.md')"
Write-Output "ARGUS_ROOT=$TargetRoot"
Write-Output "MARKER=$markerPath"
