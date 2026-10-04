[CmdletBinding()]
param(
    [string]$SourceRoot = 'C:\Tools\850-re-unified-offline',
    [Parameter(Mandatory=$true)][string]$TargetRepo,
    [string]$ExpectedBranch = 'agent/client-re-unified-active-20261004',
    [switch]$Commit,
    [switch]$Push
)

$ErrorActionPreference = 'Stop'

function Get-L850RelativePath([string]$BasePath, [string]$FullPath) {
    $base = [IO.Path]::GetFullPath($BasePath).TrimEnd('\\') + '\\'
    $full = [IO.Path]::GetFullPath($FullPath)
    if (-not $full.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside base: $FullPath"
    }
    return $full.Substring($base.Length)
}

if (-not (Test-Path -LiteralPath $SourceRoot)) { throw "Offline source missing: $SourceRoot" }
if (-not (Test-Path -LiteralPath (Join-Path $TargetRepo '.git'))) { throw "TargetRepo is not a Git worktree: $TargetRepo" }

$branch = (& git -C $TargetRepo branch --show-current).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Unable to read target branch.' }
if ($branch -ne $ExpectedBranch) { throw "Wrong target branch. Expected $ExpectedBranch, got $branch" }

$dirty = @(& git -C $TargetRepo status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'git status failed.' }
if ($dirty.Count -gt 0) { throw 'Target worktree is not clean; import aborted.' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$destRel = Join-Path 'docs\reports\offline-import' $stamp
$dest = Join-Path $TargetRepo $destRel
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$allowedNames = @('*.md','*.txt','*.json','*.py','*.ps1','*.csv')
$files = New-Object System.Collections.Generic.List[System.IO.FileInfo]
foreach ($pat in $allowedNames) {
    foreach ($f in Get-ChildItem -LiteralPath $SourceRoot -Filter $pat -File -Recurse -ErrorAction SilentlyContinue) {
        [void]$files.Add($f)
    }
}
$files = @($files | Sort-Object FullName -Unique)

$manifest = New-Object System.Collections.Generic.List[object]
foreach ($f in $files) {
    $relative = Get-L850RelativePath $SourceRoot $f.FullName
    $out = Join-Path $dest $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
    Copy-Item -LiteralPath $f.FullName -Destination $out -Force
    $hash = (Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash.ToUpperInvariant()
    [void]$manifest.Add([pscustomobject]@{
        source = $f.FullName
        imported = Get-L850RelativePath $TargetRepo $out
        sha256 = $hash
        size = $f.Length
    })
}

$manifestPath = Join-Path $dest 'IMPORT_MANIFEST.json'
[ordered]@{
    imported_at = (Get-Date).ToString('o')
    source_root = $SourceRoot
    target_repo = $TargetRepo
    target_branch = $branch
    file_count = $manifest.Count
    files = $manifest
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Output "IMPORT_DEST=$dest"
Write-Output "FILE_COUNT=$($manifest.Count)"
Write-Output "MANIFEST=$manifestPath"

if ($Commit) {
    & git -C $TargetRepo add -- $destRel
    if ($LASTEXITCODE -ne 0) { throw 'git add failed.' }
    & git -C $TargetRepo diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'git diff --cached --check failed.' }
    & git -C $TargetRepo commit -m ("docs(client-re): import offline evidence " + $stamp)
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }
    $head = (& git -C $TargetRepo rev-parse HEAD).Trim()
    Write-Output "COMMIT=$head"

    if ($Push) {
        & git -C $TargetRepo push origin $ExpectedBranch
        if ($LASTEXITCODE -ne 0) { throw 'git push failed.' }
        Write-Output 'PUSH=PASS'
    }
}
Write-Output 'STATUS=PASS'
