[CmdletBinding()]
param(
    [switch]$StaticOnly,
    [string]$WorkspaceRoot
)

$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path -Parent $PSScriptRoot
$skillsRoot = Split-Path -Parent $skillRoot
$profilePath = Join-Path $skillRoot 'config\l850-profile.json'
$masterRoute = Join-Path $skillsRoot 'scripts\master-route.ps1'
$startScript = Join-Path $PSScriptRoot 'start-l850-re.ps1'
$argusScript = Join-Path $PSScriptRoot 'check-argus-status.ps1'

$fail = New-Object System.Collections.Generic.List[string]
function Ok([string]$m) { Write-Host "[OK] $m" -ForegroundColor Green }
function Bad([string]$m) { Write-Host "[FAIL] $m" -ForegroundColor Red; [void]$fail.Add($m) }

if (-not (Test-Path -LiteralPath $profilePath)) { Bad "profile missing: $profilePath" }
else {
    try {
        $profile = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($profile.project -eq 'L850' -and $profile.client.sha256 -match '^[A-F0-9]{64}$') { Ok 'profile JSON valid' }
        else { Bad 'profile JSON fields invalid' }
    } catch { Bad ("profile JSON parse failed: " + $_.Exception.Message) }
}

$hints = @(
    '850C Lin.bin2 用 Ghidra 逆向 UseItem 與 AutoHunt',
    'L1JTW8.5 Helper PotionBridge850 反編譯 client ABI',
    'Lineage 8.5 850Launcher OwnedSkill range lifecycle reverse',
    '850C protocol reverse Ghidra MCP inventory HP MP'
)

foreach ($hint in $hints) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("l850-route-" + [guid]::NewGuid().ToString('n'))
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $masterRoute -Hint $hint -OutDir $tmp *> $null
        $scope = Join-Path $tmp 'route-scope.md'
        if (-not (Test-Path -LiteralPath $scope)) { Bad "router produced no scope for: $hint"; continue }
        $text = Get-Content -LiteralPath $scope -Raw -Encoding UTF8
        if ($text -match '(?m)^-\s*primary:\s*R46\s*
            Ok "R46 route: $hint"
        } else {
            Bad "route is not R46: $hint"
        }
    } catch {
        Bad ("router failed: " + $_.Exception.Message)
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$required = @(
    'SKILL.md',
    'references\authority-contract.md',
    'scripts\init-l850-case.ps1',
    'scripts\start-l850-re.ps1',
    'scripts\check-argus-status.ps1',
    'scripts\run-l850-bounded.ps1',
    'scripts\bounded-capstone.py',
    'scripts\import-offline-evidence.ps1',
    'scripts\verify-l850-evidence.py'
)
foreach ($rel in $required) {
    $p = Join-Path $skillRoot $rel
    if (Test-Path -LiteralPath $p) { Ok "artifact $rel" } else { Bad "missing $rel" }
}

if (-not $StaticOnly) {
    try {
        $startArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$startScript)
        if ($WorkspaceRoot) { $startArgs += @('-WorkspaceRoot',$WorkspaceRoot) }
        $out = & powershell.exe @startArgs 2>&1
        $joined = $out -join [Environment]::NewLine
        if ($joined -match 'STATUS=READY_FOR_L850_RE') { Ok 'mandatory static tool gate ready' }
        else { Bad ('start-l850-re not ready: ' + ($out -join '; ')) }
    } catch { Bad ("start-l850-re failed: " + $_.Exception.Message) }

    try {
        $argusArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$argusScript)
        if ($WorkspaceRoot) { $argusArgs += @('-WorkspaceRoot',$WorkspaceRoot) }
        $out = & powershell.exe @argusArgs 2>&1
        $joined = $out -join [Environment]::NewLine
        if ($joined -match 'ARGUS_PACKAGE_STATUS=') { Ok 'Argus status probe completed' }
        else { Bad ('Argus status probe missing fields: ' + ($out -join '; ')) }
    } catch { Bad ("Argus status probe failed: " + $_.Exception.Message) }
}

Write-Host '=== L850 SMOKE SUMMARY ==='
Write-Host ("STATIC_ONLY={0}" -f [bool]$StaticOnly)
Write-Host ("FAIL={0}" -f $fail.Count)
if ($fail.Count -gt 0) {
    $fail | ForEach-Object { Write-Host ("ERROR=" + $_) -ForegroundColor Red }
    Write-Host 'STATUS=FAIL'
    exit 1
}
Write-Host 'STATUS=PASS'
exit 0
) {
            Ok "R46 route: $hint"
        } else {
            Bad "route is not R46: $hint"
        }
    } catch {
        Bad ("router failed: " + $_.Exception.Message)
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$required = @(
    'SKILL.md',
    'references\authority-contract.md',
    'scripts\init-l850-case.ps1',
    'scripts\start-l850-re.ps1',
    'scripts\check-argus-status.ps1',
    'scripts\run-l850-bounded.ps1',
    'scripts\bounded-capstone.py',
    'scripts\import-offline-evidence.ps1',
    'scripts\verify-l850-evidence.py'
)
foreach ($rel in $required) {
    $p = Join-Path $skillRoot $rel
    if (Test-Path -LiteralPath $p) { Ok "artifact $rel" } else { Bad "missing $rel" }
}

if (-not $StaticOnly) {
    try {
        $startArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$startScript)
        if ($WorkspaceRoot) { $startArgs += @('-WorkspaceRoot',$WorkspaceRoot) }
        $out = & powershell.exe @startArgs 2>&1
        $joined = $out -join [Environment]::NewLine
        if ($joined -match 'STATUS=READY_FOR_L850_RE') { Ok 'mandatory static tool gate ready' }
        else { Bad ('start-l850-re not ready: ' + ($out -join '; ')) }
    } catch { Bad ("start-l850-re failed: " + $_.Exception.Message) }

    try {
        $argusArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$argusScript)
        if ($WorkspaceRoot) { $argusArgs += @('-WorkspaceRoot',$WorkspaceRoot) }
        $out = & powershell.exe @argusArgs 2>&1
        $joined = $out -join [Environment]::NewLine
        if ($joined -match 'ARGUS_PACKAGE_STATUS=') { Ok 'Argus status probe completed' }
        else { Bad ('Argus status probe missing fields: ' + ($out -join '; ')) }
    } catch { Bad ("Argus status probe failed: " + $_.Exception.Message) }
}

Write-Host '=== L850 SMOKE SUMMARY ==='
Write-Host ("STATIC_ONLY={0}" -f [bool]$StaticOnly)
Write-Host ("FAIL={0}" -f $fail.Count)
if ($fail.Count -gt 0) {
    $fail | ForEach-Object { Write-Host ("ERROR=" + $_) -ForegroundColor Red }
    Write-Host 'STATUS=FAIL'
    exit 1
}
Write-Host 'STATUS=PASS'
exit 0
