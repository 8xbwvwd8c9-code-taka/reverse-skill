[CmdletBinding()]
param(
    [string]$TargetRoot = 'I:\Lineage-tools\argus_mcp_reverse-skill',
    [string]$Repository = '8xbwvwd8c9-code-taka/reverse-skill',
    [string]$Ref = 'main'
)

$ErrorActionPreference = 'Stop'
$Headers = @{ 'User-Agent' = 'L850-safe-installer' }

if (-not (Test-Path -LiteralPath $TargetRoot)) {
    New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$skillsRoot = Join-Path $TargetRoot 'skills'

# A previous interrupted install may have left a partial skills tree.
# Move it aside as one unit. Argus source files outside skills are untouched.
if (Test-Path -LiteralPath $skillsRoot) {
    $wholeBackup = Join-Path $TargetRoot ("skills.backup-before-safe-l850-" + $stamp)
    Move-Item -LiteralPath $skillsRoot -Destination $wholeBackup
    Write-Output "SKILLS_BACKUP=$wholeBackup"
}
New-Item -ItemType Directory -Force -Path $skillsRoot | Out-Null

# Fixed allowlist: no directory recursion and no generic pentest/malware/exploit trees.
# This avoids PowerShell 5.1 Object[] coercion issues and avoids downloading Defender-triggering content.
$manifest = @(
    'skills/INDEX.md',
    'skills/MASTER-ROUTING.md',
    'skills/SKILL.md',
    'skills/config/routing.json',
    'skills/l850-client-re/SKILL.md',
    'skills/l850-client-re/config/l850-profile.json',
    'skills/l850-client-re/references/authority-contract.md',
    'skills/l850-client-re/references/validation-20261004.md',
    'skills/l850-client-re/scripts/bounded-capstone.py',
    'skills/l850-client-re/scripts/check-argus-status.ps1',
    'skills/l850-client-re/scripts/ghidra/L850BoundedWindow.java',
    'skills/l850-client-re/scripts/import-offline-evidence.ps1',
    'skills/l850-client-re/scripts/init-l850-case.ps1',
    'skills/l850-client-re/scripts/install-integrated-argus-root.ps1',
    'skills/l850-client-re/scripts/install-integrated-safe-subset.ps1',
    'skills/l850-client-re/scripts/run-l850-bounded.ps1',
    'skills/l850-client-re/scripts/smoke-l850.ps1',
    'skills/l850-client-re/scripts/start-l850-re.ps1',
    'skills/l850-client-re/scripts/verify-l850-evidence.py',
    'skills/routing.md',
    'skills/scripts/lib/ToolDiscovery.ps1',
    'skills/scripts/lib/WorkRoot.ps1',
    'skills/scripts/master-route.ps1'
)

$downloaded = New-Object System.Collections.Generic.List[object]

foreach ($remoteFileRaw in $manifest) {
    [string]$remoteFile = $remoteFileRaw
    if ([string]::IsNullOrWhiteSpace($remoteFile)) {
        throw 'Manifest contains an empty path.'
    }
    if (-not $remoteFile.StartsWith('skills/')) {
        throw "Unsafe manifest path outside skills/: $remoteFile"
    }

    [string]$rel = $remoteFile.Substring(7)
    [string]$dest = Join-Path -Path $skillsRoot -ChildPath ($rel -replace '/', '\')
    [string]$parent = Split-Path -Parent $dest
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    $encodedSegments = @($remoteFile -split '/' | ForEach-Object { [Uri]::EscapeDataString([string]$_) })
    [string]$encodedPath = [string]::Join('/', $encodedSegments)
    [string]$rawUrl = "https://raw.githubusercontent.com/$Repository/$Ref/$encodedPath"

    Write-Host "Downloading safe file: $remoteFile" -ForegroundColor Cyan
    Invoke-WebRequest -UseBasicParsing -Headers $Headers -Uri $rawUrl -OutFile $dest

    if (-not (Test-Path -LiteralPath $dest)) {
        throw "Downloaded file missing after request: $dest"
    }

    [string]$sha = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToUpperInvariant()
    [void]$downloaded.Add([pscustomobject]@{
        path = $remoteFile
        destination = $dest
        sha256 = $sha
    })
}

$marker = [ordered]@{
    installed_at = (Get-Date).ToString('o')
    repository = $Repository
    ref = $Ref
    target_root = $TargetRoot
    layout = 'integrated-argus-root-safe-fixed-manifest'
    manifest_count = $manifest.Count
    downloaded_count = $downloaded.Count
    downloaded = $downloaded
    excluded = @('pentest-tools','malware-analysis','attack-chain','pwn-chain','edr-bypass-re','patch-diff-exploit')
    l850_skill = 'skills\l850-client-re\SKILL.md'
    argus_root = $TargetRoot
}
$markerPath = Join-Path $TargetRoot 'L850_REVERSE_SKILL_INSTALL.json'
$marker | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $markerPath -Encoding UTF8

Write-Host ''
Write-Output 'INSTALL_STATUS=PASS'
Write-Output "TARGET_ROOT=$TargetRoot"
Write-Output "MANIFEST_COUNT=$($manifest.Count)"
Write-Output "DOWNLOADED_COUNT=$($downloaded.Count)"
Write-Output "L850_SKILL=$(Join-Path $TargetRoot 'skills\l850-client-re\SKILL.md')"
Write-Output "ARGUS_ROOT=$TargetRoot"
Write-Output "MARKER=$markerPath"

Write-Output 'READY=YES'
Write-Output 'SMOKE=NOT_RUN_AUTOMATICALLY'
