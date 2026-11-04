# Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
# Project: BVĐKKH - Remote
# Author: Nguyễn Trọng Hà

param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$statePath = 'HKLM:\SOFTWARE\BVDKKH-Remote\InstallState\BVDKKH-Remote'
$uninstallPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\BVDKKH-Remote'
$marker = 'WindowsInstaller'

$state = Get-Item -LiteralPath $statePath
if ($state.GetValueNames() -contains $marker) {
    if ($state.GetValueKind($marker) -ne 'DWord' -or $state.GetValue($marker) -notin @(0, 1)) {
        throw 'InstallState has an invalid WindowsInstaller value.'
    }
    Write-Output 'WindowsInstaller is already set. No repair needed.'
    exit 0
}

$uninstall = Get-Item -LiteralPath $uninstallPath
$location = ([string]$state.GetValue('InstallLocation')).TrimEnd('\')
$uninstallLocation = ([string]$uninstall.GetValue('InstallLocation')).TrimEnd('\')
if (-not $location -or $location -ine $uninstallLocation -or
    $uninstall.GetValueKind($marker) -ne 'DWord' -or $uninstall.GetValue($marker) -ne 0 -or
    -not (Test-Path -LiteralPath (Join-Path $location 'BVDKKH-Remote.exe') -PathType Leaf)) {
    throw 'The registry does not identify a matching EXE installation.'
}

if (-not $Apply) {
    Write-Output 'Confirmed: missing WindowsInstaller value on an EXE installation. Use -Apply to repair.'
    exit 0
}

New-ItemProperty -LiteralPath $statePath -Name $marker -PropertyType DWord -Value 0 | Out-Null
$state = Get-Item -LiteralPath $statePath
if ($state.GetValueKind($marker) -ne 'DWord' -or $state.GetValue($marker) -ne 0) {
    throw 'Could not verify the repaired WindowsInstaller value.'
}
Write-Output 'Repaired WindowsInstaller=0. The next updater check can proceed.'
