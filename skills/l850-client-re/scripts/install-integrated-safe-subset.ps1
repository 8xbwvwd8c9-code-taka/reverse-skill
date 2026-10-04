[CmdletBinding()]
param(
    [string]$TargetRoot = 'I:\Lineage-tools\argus_mcp_reverse-skill',
    [string]$Repository = '8xbwvwd8c9-code-taka/reverse-skill',
    [string]$Ref = 'main'
)

$ErrorActionPreference = 'Stop'
$ApiBase = "https://api.github.com/repos/$Repository/contents"
$Headers = @{ 'User-Agent' = 'L850-safe-installer' }

function Get-GitHubJson([string]$Path) {
    $escaped = ($Path -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
    $uri = "$ApiBase/$escaped?ref=$([Uri]::EscapeDataString($Ref))"
    return Invoke-RestMethod -UseBasicParsing -Headers $Headers -Uri $uri
}

function Download-GitHubFile([string]$Path, [string]$Destination) {
    $meta = Get-GitHubJson $Path
    if ($meta.type -ne 'file' -or -not $meta.download_url) {
        throw "Expected GitHub file: $Path"
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    Invoke-WebRequest -UseBasicParsing -Headers $Headers -Uri $meta.download_url -OutFile $Destination
}

function Copy-GitHubTree([string]$RemotePath, [string]$DestinationRoot) {
    $items = @(Get-GitHubJson $RemotePath)
    foreach ($item in $items) {
        $relative = $item.path.Substring($RemotePath.Length).TrimStart('/')
        $destination = Join-Path $DestinationRoot ($relative -replace '/', '\')
        if ($item.type -eq 'dir') {
            New-Item -ItemType Directory -Force -Path $destination | Out-Null
            Copy-GitHubTree -RemotePath $item.path -DestinationRoot $destination
        }
        elseif ($item.type -eq 'file') {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
            Invoke-WebRequest -UseBasicParsing -Headers $Headers -Uri $item.download_url -OutFile $destination
        }
    }
}

if (-not (Test-Path -LiteralPath $TargetRoot)) {
    New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$skillsRoot = Join-Path $TargetRoot 'skills'
if (Test-Path -LiteralPath $skillsRoot) {
    $wholeBackup = Join-Path $TargetRoot ("skills.backup-before-safe-l850-" + $stamp)
    Move-Item -LiteralPath $skillsRoot -Destination $wholeBackup
    Write-Output "SKILLS_BACKUP=$wholeBackup"
}
New-Item -ItemType Directory -Force -Path $skillsRoot | Out-Null

$backupRoot = Join-Path $TargetRoot ("L850-path-backup-" + $stamp)

# Only L850-related directories. Deliberately excludes pentest-tools / malware / exploit content.
$allowedDirs = @(
    'skills/l850-client-re'
)

$allowedFiles = @(
    'skills/MASTER-ROUTING.md',
    'skills/SKILL.md',
    'skills/INDEX.md',
    'skills/routing.md',
    'skills/config/routing.json',
    'skills/scripts/master-route.ps1',
    'skills/scripts/lib/WorkRoot.ps1',
    'skills/scripts/lib/ToolDiscovery.ps1'
)

function Backup-ExistingPath([string]$DestinationPath) {
    if (-not (Test-Path -LiteralPath $DestinationPath)) { return }
    $relative = $DestinationPath.Substring($TargetRoot.Length).TrimStart('\')
    $backup = Join-Path $backupRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
    Move-Item -LiteralPath $DestinationPath -Destination $backup
    Write-Output "BACKUP=$backup"
}

foreach ($remoteDir in $allowedDirs) {
    $rel = $remoteDir.Substring('skills/'.Length)
    $dest = Join-Path $skillsRoot ($rel -replace '/', '\')
    Backup-ExistingPath $dest
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Write-Host "Downloading safe tree: $remoteDir" -ForegroundColor Cyan
    Copy-GitHubTree -RemotePath $remoteDir -DestinationRoot $dest
}

foreach ($remoteFile in $allowedFiles) {
    $rel = $remoteFile.Substring('skills/'.Length)
    $dest = Join-Path $skillsRoot ($rel -replace '/', '\')
    Backup-ExistingPath $dest
    Write-Host "Downloading safe file: $remoteFile" -ForegroundColor Cyan
    Download-GitHubFile -Path $remoteFile -Destination $dest
}

$marker = [ordered]@{
    installed_at = (Get-Date).ToString('o')
    repository = $Repository
    ref = $Ref
    target_root = $TargetRoot
    layout = 'integrated-argus-root-safe-subset'
    excluded = @('pentest-tools','malware-analysis','attack-chain','pwn-chain','edr-bypass-re','patch-diff-exploit')
    l850_skill = 'skills\l850-client-re\SKILL.md'
    argus_root = $TargetRoot
}
$markerPath = Join-Path $TargetRoot 'L850_REVERSE_SKILL_INSTALL.json'
$marker | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $markerPath -Encoding UTF8

Write-Host ''
Write-Output 'INSTALL_STATUS=PASS'
Write-Output "TARGET_ROOT=$TargetRoot"
Write-Output "L850_SKILL=$(Join-Path $TargetRoot 'skills\l850-client-re\SKILL.md')"
Write-Output "ARGUS_ROOT=$TargetRoot"
Write-Output "MARKER=$markerPath"

$smoke = Join-Path $TargetRoot 'skills\l850-client-re\scripts\smoke-l850.ps1'
if (Test-Path -LiteralPath $smoke) {
    Write-Host ''
    Write-Host 'Running L850 smoke...' -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $smoke
    Write-Output "SMOKE_EXIT=$LASTEXITCODE"
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Safe subset installed, but smoke reported a local tool/config blocker.'
        exit $LASTEXITCODE
    }
}
Write-Output 'READY=YES'
