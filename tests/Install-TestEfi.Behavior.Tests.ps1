$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$module = Import-Module (Join-Path $root 'scripts\PortStation.Install.psm1') -Force -PassThru

$state = @{
    Disk = $null
    Partitions = @()
    Volumes = @{}
    SourceHash = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    DestinationHash = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    MutationCalls = 0
    StorageCalls = 0
}

& $module {
    param($TestState)
    $script:BehaviorTestState = $TestState

    function script:Test-PortStationSourceFile { $true }
    function script:Get-PortStationDisk {
        $script:BehaviorTestState.StorageCalls++
        $script:BehaviorTestState.Disk
    }
    function script:Get-PortStationPartitions {
        $script:BehaviorTestState.StorageCalls++
        @($script:BehaviorTestState.Partitions)
    }
    function script:Get-PortStationVolume {
        param([char]$DriveLetter)
        $script:BehaviorTestState.StorageCalls++
        $script:BehaviorTestState.Volumes[[string]$DriveLetter]
    }
    function script:New-PortStationDirectory {
        $script:BehaviorTestState.MutationCalls++
    }
    function script:Copy-PortStationFile {
        $script:BehaviorTestState.MutationCalls++
    }
    function script:Get-PortStationFileHash {
        param([string]$LiteralPath)
        if ($LiteralPath -eq 'X:\fixture\BOOTX64.EFI') {
            [pscustomobject]@{ Hash = $script:BehaviorTestState.SourceHash }
        }
        else {
            [pscustomobject]@{ Hash = $script:BehaviorTestState.DestinationHash }
        }
    }
} $state

function Reset-TestState {
    $state.Disk = [pscustomobject]@{
        BusType = 'USB'
        IsBoot = $false
        IsSystem = $false
        FriendlyName = 'Behavioral stub target'
        Size = 32GB
    }
    $state.Partitions = @([pscustomobject]@{ DriveLetter = 'T' })
    $state.Volumes = @{ T = [pscustomobject]@{ FileSystem = 'FAT32' } }
    $state.SourceHash = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    $state.DestinationHash = $state.SourceHash
    $state.MutationCalls = 0
    $state.StorageCalls = 0
}

function Invoke-Installer {
    param([int]$DiskNumber = 7)
    Install-PortStationEfi -DiskNumber $DiskNumber -KernelImage 'X:\fixture\BOOTX64.EFI' -Confirm:$false
}

function Assert-Refused {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Arrange,
        [int]$DiskNumber = 7
    )
    Reset-TestState
    & $Arrange
    $errorId = $null
    try { Invoke-Installer -DiskNumber $DiskNumber | Out-Null } catch { $errorId = $_.FullyQualifiedErrorId }
    if ($errorId -notlike 'PortStation.TargetRefused*') {
        throw "$Name returned '$errorId' instead of the target-refused contract."
    }
    if ($state.MutationCalls -ne 0) { throw "$Name crossed the mutation boundary." }
    Write-Host "$Name=PASS"
}

Assert-Refused -Name 'DISK0_REFUSAL' -DiskNumber 0 -Arrange {}
Assert-Refused -Name 'NON_USB_REFUSAL' -Arrange { $state.Disk.BusType = 'SATA' }
Assert-Refused -Name 'BOOT_DISK_REFUSAL' -Arrange { $state.Disk.IsBoot = $true }
Assert-Refused -Name 'SYSTEM_DISK_REFUSAL' -Arrange { $state.Disk.IsSystem = $true }
Assert-Refused -Name 'ZERO_FAT32_REFUSAL' -Arrange { $state.Partitions = @() }
Assert-Refused -Name 'MULTI_FAT32_REFUSAL' -Arrange {
    $state.Partitions = @(
        [pscustomobject]@{ DriveLetter = 'T' },
        [pscustomobject]@{ DriveLetter = 'U' }
    )
    $state.Volumes.U = [pscustomobject]@{ FileSystem = 'FAT32' }
}

Reset-TestState
$result = Invoke-Installer
if ($state.MutationCalls -ne 2 -or -not $result.Verified) {
    throw 'Valid target did not reach and complete the mocked mutation boundary.'
}
Write-Host 'VALID_TARGET_BOUNDARY=PASS'

Reset-TestState
Install-PortStationEfi -DiskNumber 7 -KernelImage 'X:\fixture\BOOTX64.EFI' -WhatIf | Out-Null
if ($state.MutationCalls -ne 0) { throw 'WhatIf crossed the mocked mutation boundary.' }
Write-Host 'SHOULDPROCESS_REFUSAL=PASS'

Reset-TestState
$state.DestinationHash = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'
$errorId = $null
try { Invoke-Installer | Out-Null } catch { $errorId = $_.FullyQualifiedErrorId }
if ($errorId -notlike 'PortStation.HashMismatch*') { throw 'Hash mismatch did not return the verification-failure contract.' }
if ($state.MutationCalls -ne 2) { throw 'Hash mismatch test did not use only the mocked mutation boundary.' }
Write-Host 'HASH_MISMATCH_FAILURE=PASS'
Write-Host 'REAL_STORAGE_MUTATION_DURING_TESTS=FALSE'
Write-Host 'BEHAVIORAL_REFUSAL_TESTS=PASS'
