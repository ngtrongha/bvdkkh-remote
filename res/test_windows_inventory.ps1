# Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
# Project: BVĐKKH - Remote
# Author: Nguyễn Trọng Hà

$ErrorActionPreference = 'Stop'
$source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../src/common.rs') -Raw -Encoding UTF8
$gpuStart = $source.IndexOf('$gpuControllers = @(')
$gpuEnd = $source.IndexOf('# 10. Printers', $gpuStart)
$gpuScript = [scriptblock]::Create($source.Substring($gpuStart, $gpuEnd - $gpuStart))
$diskStart = $source.IndexOf('$physicalMedia = @(')
$diskEnd = $source.IndexOf('# 8. Monitors', $diskStart)
$diskScript = [scriptblock]::Create($source.Substring($diskStart, $diskEnd - $diskStart))

function Assert-Equal($actual, $expected, [string]$message) {
    if ($actual -ne $expected) { throw $message }
}

function Get-WmiCompat([string]$className, [string]$namespace) {
    switch ($className) {
        'Win32_VideoController' { $script:controllers }
        'Win32_PhysicalMedia' {
            [pscustomobject]@{ Tag = '\\.\PHYSICALDRIVE0'; SerialNumber = 'DISK-SERIAL' }
        }
        'MSFT_PhysicalDisk' {
            [pscustomobject]@{ SerialNumber = 'DISK-SERIAL'; MediaType = 4 }
        }
        'Win32_DiskDrive' {
            [pscustomobject]@{
                DeviceID = '\\.\PHYSICALDRIVE0'; Model = 'Generic disk'; SerialNumber = ''
                Size = 512GB; InterfaceType = 'SCSI'; MediaType = 'Fixed hard disk media'
            }
        }
    }
}

$controllers = @([pscustomobject]@{ Name = 'NVIDIA Test'; PNPDeviceID = 'PCI-1' })
$nvidiaInfo = @([pscustomobject]@{ Name = 'NVIDIA Test'; SerialNumber = 'BOARD-SERIAL'; UUID = 'GPU-ID' })
. $gpuScript
Assert-Equal $gpus.Count 1 'Missing GPU'
Assert-Equal $gpus[0].SerialNumber 'BOARD-SERIAL' 'Vendor serial missing'
Assert-Equal $gpus[0].UUID 'GPU-ID' 'GPU UUID must remain distinct from serial'
Assert-Equal $gpus[0].PNPDeviceID 'PCI-1' 'PnP ID missing'

$nvidiaInfo[0].SerialNumber = '[N/A]'
. $gpuScript
Assert-Equal $gpus[0].SerialNumber '' 'Unsupported serial must remain empty'
Assert-Equal $gpus[0].UUID 'GPU-ID' 'Do not substitute UUID as serial'

$controllers += [pscustomobject]@{ Name = 'NVIDIA Test'; PNPDeviceID = 'PCI-2' }
. $gpuScript
Assert-Equal $gpus[0].SerialNumber '' 'Ambiguous model must not inherit another board serial'
Assert-Equal $gpus[1].UUID '' 'Ambiguous model must not inherit another board UUID'

. $diskScript
Assert-Equal $physDisks[0].SerialNumber 'DISK-SERIAL' 'Physical media serial fallback failed'
Assert-Equal $physDisks[0].MediaType 'SSD' 'Storage media type must identify SSD without name heuristics'
Write-Output '[OK] GPU serial/UUID, unavailable serial, ambiguous GPU, disk serial fallback and SSD classification'
