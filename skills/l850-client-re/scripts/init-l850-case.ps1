[CmdletBinding()]
param(
    [string]$ProfilePath = (Join-Path $PSScriptRoot '..\config\l850-profile.json'),
    [string]$ClientPath,
    [string]$RuntimeImagePath,
    [string]$WorkspaceRoot
)

$ErrorActionPreference = 'Stop'

function Get-Sha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing file: $Path"
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

$profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json

if (-not $ClientPath) { $ClientPath = $profile.client.defaultPath }
if (-not $RuntimeImagePath) { $RuntimeImagePath = $profile.runtimeImage.defaultPath }
if (-not $WorkspaceRoot) { $WorkspaceRoot = $profile.workspace.offlineRoot }

$clientHash = Get-Sha256 $ClientPath
$runtimeHash = Get-Sha256 $RuntimeImagePath

if ($clientHash -ne $profile.client.sha256) {
    throw "CLIENT_SHA256 mismatch. Expected $($profile.client.sha256), got $clientHash"
}
if ($runtimeHash -ne $profile.runtimeImage.sha256) {
    throw "RUNTIME_IMAGE_SHA256 mismatch. Expected $($profile.runtimeImage.sha256), got $runtimeHash"
}

$evidenceDir = Join-Path $WorkspaceRoot $profile.workspace.evidenceDir
$scriptsDir = Join-Path $WorkspaceRoot $profile.workspace.scriptsDir
New-Item -ItemType Directory -Force -Path $WorkspaceRoot,$evidenceDir,$scriptsDir | Out-Null

$case = [ordered]@{
    Project = $profile.project
    ClientPath = $ClientPath
    ClientSha256 = $clientHash
    RuntimeImagePath = $RuntimeImagePath
    RuntimeImageSha256 = $runtimeHash
    ImageBase = $profile.client.imageBase
    WorkspaceRoot = $WorkspaceRoot
    EvidenceDir = $evidenceDir
    ScriptsDir = $scriptsDir
    ArgusPath = $profile.argus.defaultPath
    GeneratedAt = (Get-Date).ToString('o')
}

$casePath = Join-Path $WorkspaceRoot 'l850-case.json'
$case | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $casePath -Encoding UTF8

$reportPath = Join-Path $WorkspaceRoot $profile.workspace.report
if (-not (Test-Path -LiteralPath $reportPath)) {
@"
# L850 Unified Offline RE Report

CLIENT_SHA256=$clientHash
RUNTIME_IMAGE_SHA256=$runtimeHash
IMAGE_BASE=$($profile.client.imageBase)
ARGUS_PATH=$($profile.argus.defaultPath)

## Timeline

"@ | Set-Content -LiteralPath $reportPath -Encoding UTF8
}

Write-Output "STATUS=PASS"
Write-Output "CLIENT_SHA256=$clientHash"
Write-Output "RUNTIME_IMAGE_SHA256=$runtimeHash"
Write-Output "WORKSPACE=$WorkspaceRoot"
Write-Output "CASE=$casePath"
Write-Output "REPORT=$reportPath"
Write-Output "NEXT=Run bounded Ghidra/Capstone from the highest-priority unresolved L850 item."
