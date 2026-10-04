[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$VA,
    [int]$Before = 0x20,
    [int]$After = 0x80,
    [string]$WorkspaceRoot,
    [string]$RuntimeImagePath,
    [string]$GhidraProjectDir,
    [string]$GhidraProjectName,
    [string]$GhidraProgramName
)

$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path -Parent $PSScriptRoot
$profilePath = Join-Path $skillRoot 'config\l850-profile.json'
$toolDiscovery = Join-Path $skillRoot '..\scripts\lib\ToolDiscovery.ps1'
. $toolDiscovery
$profile = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $WorkspaceRoot) { $WorkspaceRoot = $profile.workspace.offlineRoot }
if (-not $RuntimeImagePath) { $RuntimeImagePath = $profile.runtimeImage.defaultPath }
New-Item -ItemType Directory -Force -Path $WorkspaceRoot | Out-Null
$evidenceDir = Join-Path $WorkspaceRoot $profile.workspace.evidenceDir
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null

$python = Resolve-ReverseToolSpec -Name 'python'
$ghidra = Resolve-ReverseToolSpec -Name 'analyzeHeadless'
if (-not $python.Available) { throw 'Python unavailable.' }

$vaNum = [Convert]::ToUInt32(($VA -replace '^0x',''),16)
$baseNum = [Convert]::ToUInt32(([string]$profile.client.imageBase -replace '^0x',''),16)
$startNum = [Math]::Max($baseNum, $vaNum - $Before)
$endNum = $vaNum + $After
$tag = ('{0:X8}' -f $vaNum)
$capOut = Join-Path $evidenceDir ("capstone-$tag.json")
$ghidraOut = Join-Path $evidenceDir ("ghidra-$tag.txt")

$capScript = Join-Path $PSScriptRoot 'bounded-capstone.py'
& $python.ResolvedPath $capScript --image $RuntimeImagePath --va ("0x{0:X8}" -f $vaNum) --before $Before --after $After --base $profile.client.imageBase --expected-sha256 $profile.runtimeImage.sha256 --output $capOut
if ($LASTEXITCODE -ne 0) { throw "Capstone bounded proof failed for $VA" }

Write-Output "CAPSTONE_STATUS=PASS"
Write-Output "CAPSTONE_EVIDENCE=$capOut"

$ghidraStatus = 'SKIPPED_NO_PROJECT'
if ($GhidraProjectDir -and $GhidraProjectName -and $GhidraProgramName) {
    if (-not $ghidra.Available) { throw 'Ghidra analyzeHeadless unavailable.' }
    $scriptDir = Join-Path $PSScriptRoot 'ghidra'
    $args = @(
        $GhidraProjectDir,
        $GhidraProjectName,
        '-process', $GhidraProgramName,
        '-noanalysis',
        '-scriptPath', $scriptDir,
        '-postScript', 'L850BoundedWindow.java',
        ("0x{0:X8}" -f $startNum),
        ("0x{0:X8}" -f $endNum),
        $ghidraOut
    )
    & $ghidra.ResolvedPath @args
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $ghidraOut)) {
        throw "Ghidra bounded window failed for $VA"
    }
    $ghidraStatus = 'PASS'
}

Write-Output "GHIDRA_STATUS=$ghidraStatus"
if (Test-Path -LiteralPath $ghidraOut) { Write-Output "GHIDRA_EVIDENCE=$ghidraOut" }
Write-Output 'WHOLE_IMAGE_ANALYSIS=NO'
Write-Output 'MEMORY_WRITE=NO'
Write-Output 'PACKET_SEND=NO'
Write-Output 'GAME_ACTION=NO'
Write-Output 'STATUS=PASS'
