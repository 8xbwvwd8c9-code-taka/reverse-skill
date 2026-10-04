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
    $backup = Join-Path $TargetRoot ("skills.backup-" + $stamp)
    Move-Item -LiteralPath $targetSkills -Destination $backup
    Write-Output "SKILLS_BACKUP=$backup"
}

Copy-Item -LiteralPath $sourceSkills -Destination $targetSkills -Recurse -Force

$marker = [ordered]@{
    installed_at = (Get-Date).ToString('o')
    source_root = $SourceRoot
    target_root = $TargetRoot
    layout = 'integrated-argus-root'
    l850_skill = 'skills\l850-client-re\SKILL.md'
    argus_root = $TargetRoot
}
$markerPath = Join-Path $TargetRoot 'L850_REVERSE_SKILL_INSTALL.json'
$marker | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $markerPath -Encoding UTF8

Write-Output 'STATUS=PASS'
Write-Output "TARGET_ROOT=$TargetRoot"
Write-Output "L850_SKILL=$(Join-Path $TargetRoot 'skills\l850-client-re\SKILL.md')"
Write-Output "ARGUS_ROOT=$TargetRoot"
Write-Output "MARKER=$markerPath"
