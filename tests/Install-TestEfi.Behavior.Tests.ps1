$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$module = Import-Module (Join-Path $root 'scripts\PortStation.Install.psm1') -Force -PassThru
$source = 'X:\fixture\BOOTX64.EFI'
$volumeId = '\\?\Volume{11111111-2222-3333-4444-555555555555}\'
$destination = "$($volumeId.TrimEnd('\'))\EFI\BOOT\BOOTX64.EFI"
$staged = "$($volumeId.TrimEnd('\'))\EFI\BOOT\.BOOTX64.EFI.portstation.new"
$backup = "$($volumeId.TrimEnd('\'))\EFI\BOOT\.BOOTX64.EFI.portstation.previous"
$goodHash = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
$oldHash = 'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC'
$badHash = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'

& $module {
    $bytes = [byte[]]::new(256)
    ([BitConverter]::GetBytes([uint16]0x5A4D)).CopyTo($bytes, 0)
    ([BitConverter]::GetBytes([uint32]64)).CopyTo($bytes, 0x3C)
    ([BitConverter]::GetBytes([uint32]0x00004550)).CopyTo($bytes, 64)
    ([BitConverter]::GetBytes([uint16]0x8664)).CopyTo($bytes, 68)
    ([BitConverter]::GetBytes([uint16]70)).CopyTo($bytes, 84)
    ([BitConverter]::GetBytes([uint16]0x0002)).CopyTo($bytes, 86)
    ([BitConverter]::GetBytes([uint16]0x020B)).CopyTo($bytes, 88)
    ([BitConverter]::GetBytes([uint16]10)).CopyTo($bytes, 156)
    $stream = [System.IO.MemoryStream]::new($bytes, $false)
    $info = Read-PortStationEfiImageInfo -Stream $stream
    if ($info.Machine -ne 0x8664 -or $info.OptionalMagic -ne 0x020B -or $info.Subsystem -ne 10 -or $info.Characteristics -ne 0x0002) {
        throw 'In-memory valid EFI header was parsed incorrectly.'
    }

    ([BitConverter]::GetBytes([uint16]2)).CopyTo($bytes, 84)
    $stream = [System.IO.MemoryStream]::new($bytes, $false)
    $refused = $false
    try { Read-PortStationEfiImageInfo -Stream $stream | Out-Null } catch { $refused = $true }
    if (-not $refused) { throw 'Truncated PE optional header was accepted.' }
}
Write-Host 'EFI_HEADER_PARSER=PASS'

$state = @{
    Disk = $null
    DiskAfterQualification = $null
    Partitions = @()
    Volumes = @{}
    Existing = @{}
    FileHashes = @{}
    SourceHash = $goodHash
    SourceHashAfterQualification = $null
    SourceHashCalls = 0
    DiskCalls = 0
    StorageCalls = 0
    Calls = [System.Collections.ArrayList]::new()
    InvalidImage = $false
    ImageCharacteristics = 0x0002
    ImageInfoCalls = 0
    CorruptStage = $false
    CorruptBackup = $false
    CorruptInstall = $false
    CorruptRollback = $false
}

& $module {
    param($TestState, $SourcePath, $DestinationPath, $StagedPath, $BackupPath, $BadHash)
    $script:BehaviorTestState = $TestState
    $script:BehaviorSource = $SourcePath
    $script:BehaviorDestination = $DestinationPath
    $script:BehaviorStaged = $StagedPath
    $script:BehaviorBackup = $BackupPath
    $script:BehaviorBadHash = $BadHash

    function script:Get-PortStationEfiImageInfo {
        $script:BehaviorTestState.ImageInfoCalls++
        if ($script:BehaviorTestState.InvalidImage) {
            return [pscustomobject]@{ Length = 4; Machine = 0; OptionalMagic = 0; Subsystem = 0; Characteristics = 0 }
        }
        [pscustomobject]@{ Length = 4096; Machine = 0x8664; OptionalMagic = 0x020B; Subsystem = 10; Characteristics = $script:BehaviorTestState.ImageCharacteristics }
    }
    function script:Get-PortStationDisk {
        $script:BehaviorTestState.StorageCalls++
        $script:BehaviorTestState.DiskCalls++
        if ($script:BehaviorTestState.DiskCalls -gt 1 -and $script:BehaviorTestState.DiskAfterQualification) {
            return $script:BehaviorTestState.DiskAfterQualification
        }
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
    function script:Test-PortStationPath {
        param([string]$LiteralPath)
        [bool]$script:BehaviorTestState.Existing[$LiteralPath]
    }
    function script:New-PortStationDirectory {
        param([string]$Path)
        [void]$script:BehaviorTestState.Calls.Add([pscustomobject]@{ Kind = 'NewDirectory'; Source = $null; Destination = $Path })
    }
    function script:Copy-PortStationFile {
        param([string]$LiteralPath, [string]$Destination)
        [void]$script:BehaviorTestState.Calls.Add([pscustomobject]@{ Kind = 'Copy'; Source = $LiteralPath; Destination = $Destination })
        $script:BehaviorTestState.Existing[$Destination] = $true
        if ($LiteralPath -eq $script:BehaviorSource) {
            $script:BehaviorTestState.FileHashes[$Destination] = if ($script:BehaviorTestState.CorruptStage) { $script:BehaviorBadHash } else { $script:BehaviorTestState.SourceHash }
        }
        else {
            $script:BehaviorTestState.FileHashes[$Destination] = $script:BehaviorTestState.FileHashes[$LiteralPath]
            if ($Destination -eq $script:BehaviorBackup -and $script:BehaviorTestState.CorruptBackup) {
                $script:BehaviorTestState.FileHashes[$Destination] = $script:BehaviorBadHash
            }
        }
    }
    function script:Move-PortStationFile {
        param([string]$LiteralPath, [string]$Destination)
        [void]$script:BehaviorTestState.Calls.Add([pscustomobject]@{ Kind = 'Move'; Source = $LiteralPath; Destination = $Destination })
        $script:BehaviorTestState.Existing[$Destination] = $true
        $script:BehaviorTestState.FileHashes[$Destination] = $script:BehaviorTestState.FileHashes[$LiteralPath]
        if ($LiteralPath -eq $script:BehaviorStaged -and $script:BehaviorTestState.CorruptInstall) {
            $script:BehaviorTestState.FileHashes[$Destination] = $script:BehaviorBadHash
        }
        if ($LiteralPath -eq $script:BehaviorBackup -and $script:BehaviorTestState.CorruptRollback) {
            $script:BehaviorTestState.FileHashes[$Destination] = $script:BehaviorBadHash
        }
        $script:BehaviorTestState.Existing[$LiteralPath] = $false
    }
    function script:Remove-PortStationFile {
        param([string]$LiteralPath)
        [void]$script:BehaviorTestState.Calls.Add([pscustomobject]@{ Kind = 'Remove'; Source = $LiteralPath; Destination = $null })
        $script:BehaviorTestState.Existing[$LiteralPath] = $false
    }
    function script:Get-PortStationFileHash {
        param([string]$LiteralPath)
        if ($LiteralPath -eq $script:BehaviorSource) {
            $script:BehaviorTestState.SourceHashCalls++
            $hash = if ($script:BehaviorTestState.SourceHashCalls -gt 1 -and $script:BehaviorTestState.SourceHashAfterQualification) {
                $script:BehaviorTestState.SourceHashAfterQualification
            }
            else { $script:BehaviorTestState.SourceHash }
            return [pscustomobject]@{ Hash = $hash }
        }
        [pscustomobject]@{ Hash = $script:BehaviorTestState.FileHashes[$LiteralPath] }
    }
} $state $source $destination $staged $backup $badHash

function Reset-TestState {
    $state.Disk = [pscustomobject]@{
        Number = 7; UniqueId = 'disk-7'; SerialNumber = 'serial-7'; Size = 32GB
        BusType = 'USB'; IsBoot = $false; IsSystem = $false; IsOffline = $false; IsReadOnly = $false; PartitionStyle = 'GPT'
        FriendlyName = 'Behavioral stub target'
    }
    $state.DiskAfterQualification = $null
    $state.Partitions = @([pscustomobject]@{
        DiskNumber = 7; PartitionNumber = 1; DriveLetter = 'T'; Guid = 'partition-1'
        Offset = 1MB; Size = 31GB
    })
    $state.Volumes = @{ T = [pscustomobject]@{ FileSystem = 'FAT32'; UniqueId = $volumeId } }
    $state.Existing = @{ $destination = $true; $staged = $false; $backup = $false }
    $state.FileHashes = @{ $destination = $oldHash }
    $state.SourceHash = $goodHash
    $state.SourceHashAfterQualification = $null
    $state.SourceHashCalls = 0
    $state.DiskCalls = 0
    $state.StorageCalls = 0
    $state.Calls.Clear()
    $state.InvalidImage = $false
    $state.ImageCharacteristics = 0x0002
    $state.ImageInfoCalls = 0
    $state.CorruptStage = $false
    $state.CorruptBackup = $false
    $state.CorruptInstall = $false
    $state.CorruptRollback = $false
}

function Invoke-Installer {
    param([int]$DiskNumber = 7, [switch]$WhatIf)
    if ($WhatIf) { Install-PortStationEfi -DiskNumber $DiskNumber -KernelImage $source -WhatIf }
    else { Install-PortStationEfi -DiskNumber $DiskNumber -KernelImage $source -Confirm:$false }
}

function Assert-ErrorContract {
    param([string]$Name, [string]$ExpectedId, [scriptblock]$Act)
    $errorId = $null
    try { & $Act | Out-Null } catch { $errorId = $_.FullyQualifiedErrorId }
    if ($errorId -notlike "$ExpectedId*") { throw "$Name returned '$errorId' instead of '$ExpectedId'." }
    Write-Host "$Name=PASS"
}

function Assert-NoMutation {
    param([string]$Name)
    if ($state.Calls.Count -ne 0) { throw "$Name crossed the mocked mutation boundary." }
}

Reset-TestState
Assert-ErrorContract 'DISK0_REFUSAL' 'PortStation.TargetRefused' { Invoke-Installer -DiskNumber 0 }
Assert-NoMutation 'DISK0_REFUSAL'
if ($state.StorageCalls -ne 0) { throw 'Disk 0 was enumerated.' }
if ($state.ImageInfoCalls -ne 0) { throw 'Disk 0 caused source-image inspection.' }

Reset-TestState
$state.Disk.BusType = 'SATA'
Assert-ErrorContract 'NON_USB_REFUSAL' 'PortStation.TargetRefused' { Invoke-Installer }
Assert-NoMutation 'NON_USB_REFUSAL'

Reset-TestState
$state.Disk.IsBoot = $true
Assert-ErrorContract 'BOOT_DISK_REFUSAL' 'PortStation.TargetRefused' { Invoke-Installer }
Assert-NoMutation 'BOOT_DISK_REFUSAL'

Reset-TestState
$state.Disk.IsSystem = $true
Assert-ErrorContract 'SYSTEM_DISK_REFUSAL' 'PortStation.TargetRefused' { Invoke-Installer }
Assert-NoMutation 'SYSTEM_DISK_REFUSAL'

Reset-TestState
$state.Disk.PartitionStyle = 'MBR'
Assert-ErrorContract 'NON_GPT_REFUSAL' 'PortStation.TargetRefused' { Invoke-Installer }
Assert-NoMutation 'NON_GPT_REFUSAL'

Reset-TestState
$state.Disk.IsOffline = $true
Assert-ErrorContract 'OFFLINE_DISK_REFUSAL' 'PortStation.TargetRefused' { Invoke-Installer }
Assert-NoMutation 'OFFLINE_DISK_REFUSAL'

Reset-TestState
$state.Disk.IsReadOnly = $true
Assert-ErrorContract 'READ_ONLY_DISK_REFUSAL' 'PortStation.TargetRefused' { Invoke-Installer }
Assert-NoMutation 'READ_ONLY_DISK_REFUSAL'

Reset-TestState
$state.Volumes.T.FileSystem = 'NTFS'
Assert-ErrorContract 'ZERO_FAT32_REFUSAL' 'PortStation.TargetRefused' { Invoke-Installer }
Assert-NoMutation 'ZERO_FAT32_REFUSAL'

Reset-TestState
$state.Partitions += [pscustomobject]@{ DiskNumber = 7; PartitionNumber = 2; DriveLetter = 'U'; Guid = 'partition-2'; Offset = 32GB; Size = 1GB }
$state.Volumes.U = [pscustomobject]@{ FileSystem = 'FAT32'; UniqueId = 'volume-u' }
Assert-ErrorContract 'MULTI_FAT32_REFUSAL' 'PortStation.TargetRefused' { Invoke-Installer }
Assert-NoMutation 'MULTI_FAT32_REFUSAL'

Reset-TestState
$state.Volumes.T.UniqueId = ''
Assert-ErrorContract 'MISSING_IDENTITY_REFUSAL' 'PortStation.TargetRefused' { Invoke-Installer }
Assert-NoMutation 'MISSING_IDENTITY_REFUSAL'

Reset-TestState
$state.InvalidImage = $true
Assert-ErrorContract 'INVALID_EFI_REFUSAL' 'PortStation.SourceInvalid' { Invoke-Installer }
Assert-NoMutation 'INVALID_EFI_REFUSAL'
if ($state.StorageCalls -ne 0) { throw 'Invalid image caused storage enumeration.' }

Reset-TestState
$state.ImageCharacteristics = 0x2002
Assert-ErrorContract 'EFI_DLL_REFUSAL' 'PortStation.SourceInvalid' { Invoke-Installer }
Assert-NoMutation 'EFI_DLL_REFUSAL'
if ($state.StorageCalls -ne 0) { throw 'EFI DLL caused storage enumeration.' }

Reset-TestState
$state.DiskAfterQualification = $state.Disk.PSObject.Copy()
$state.DiskAfterQualification.UniqueId = 'different-disk'
Assert-ErrorContract 'TARGET_CHANGE_REFUSAL' 'PortStation.TargetChanged' { Invoke-Installer }
Assert-NoMutation 'TARGET_CHANGE_REFUSAL'

Reset-TestState
$state.SourceHashAfterQualification = $badHash
Assert-ErrorContract 'SOURCE_CHANGE_REFUSAL' 'PortStation.SourceChanged' { Invoke-Installer }
Assert-NoMutation 'SOURCE_CHANGE_REFUSAL'

Reset-TestState
Invoke-Installer -WhatIf | Out-Null
Assert-NoMutation 'SHOULDPROCESS_REFUSAL'
Write-Host 'SHOULDPROCESS_REFUSAL=PASS'

Reset-TestState
$result = Invoke-Installer
if (-not $result.Verified -or $result.Destination -ne $destination) { throw 'Valid target did not return the verified destination contract.' }
$copies = @($state.Calls | Where-Object Kind -eq 'Copy')
$moves = @($state.Calls | Where-Object Kind -eq 'Move')
if ($copies.Count -ne 2 -or $copies[0].Source -ne $source -or $copies[0].Destination -ne $staged) { throw 'Source was not staged at the exact qualified path.' }
if ($copies[1].Source -ne $destination -or $copies[1].Destination -ne $backup) { throw 'Existing boot image was not backed up at the exact qualified path.' }
if ($moves.Count -ne 1 -or $moves[0].Source -ne $staged -or $moves[0].Destination -ne $destination) { throw 'Staged image was not moved to the exact qualified destination.' }
if ($state.StorageCalls -ne 6) { throw 'Valid install did not perform exactly two complete target snapshots.' }
if ($state.FileHashes[$destination] -ne $goodHash) { throw 'Valid install did not leave the qualified image at the destination.' }
Write-Host 'VALID_TARGET_BOUNDARY=PASS'

Reset-TestState
$state.CorruptStage = $true
Assert-ErrorContract 'HASH_MISMATCH_FAILURE' 'PortStation.HashMismatch' { Invoke-Installer }
if ($state.FileHashes[$destination] -ne $oldHash) { throw 'Staged hash mismatch altered the live image.' }
if (@($state.Calls | Where-Object Kind -eq 'Move').Count -ne 0) { throw 'Staged hash mismatch reached replacement.' }

Reset-TestState
$state.CorruptBackup = $true
Assert-ErrorContract 'BACKUP_MISMATCH_FAILURE' 'PortStation.HashMismatch' { Invoke-Installer }
if ($state.FileHashes[$destination] -ne $oldHash) { throw 'Rollback-copy mismatch altered the live image.' }
if (@($state.Calls | Where-Object Kind -eq 'Move').Count -ne 0) { throw 'Rollback-copy mismatch reached replacement.' }

Reset-TestState
$state.CorruptInstall = $true
Assert-ErrorContract 'ROLLBACK_ON_INSTALL_FAILURE' 'PortStation.InstallFailed' { Invoke-Installer }
if ($state.FileHashes[$destination] -ne $oldHash) { throw 'Failed installed verification did not restore the prior image.' }

Reset-TestState
$state.CorruptInstall = $true
$state.CorruptRollback = $true
Assert-ErrorContract 'ROLLBACK_MISMATCH_FAILURE' 'PortStation.RollbackFailed' { Invoke-Installer }

Write-Host 'REAL_STORAGE_MUTATION_DURING_TESTS=FALSE'
Write-Host 'BEHAVIORAL_REFUSAL_TESTS=PASS'
