$ErrorActionPreference = 'Stop'

function New-PortStationErrorRecord {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)]$TargetObject
    )
    $exception = [System.InvalidOperationException]::new($Message)
    [System.Management.Automation.ErrorRecord]::new(
        $exception,
        $Id,
        [System.Management.Automation.ErrorCategory]::SecurityError,
        $TargetObject
    )
}

function Get-PortStationDisk {
    param([Parameter(Mandatory)][int]$Number)
    Get-Disk -Number $Number
}

function Get-PortStationPartitions {
    param([Parameter(Mandatory)][int]$DiskNumber)
    @(Get-Partition -DiskNumber $DiskNumber)
}

function Get-PortStationVolume {
    param([Parameter(Mandatory)][char]$DriveLetter)
    Get-Volume -DriveLetter $DriveLetter
}

function Test-PortStationPath {
    param([Parameter(Mandatory)][string]$LiteralPath)
    Test-Path -LiteralPath $LiteralPath -PathType Leaf
}

function New-PortStationDirectory {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Copy-PortStationFile {
    param(
        [Parameter(Mandatory)][string]$LiteralPath,
        [Parameter(Mandatory)][string]$Destination
    )
    $read = [System.IO.File]::Open(
        $LiteralPath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read
    )
    try {
        $options = [System.IO.FileOptions]::SequentialScan -bor [System.IO.FileOptions]::WriteThrough
        $write = [System.IO.FileStream]::new(
            $Destination,
            [System.IO.FileMode]::Create,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None,
            1MB,
            $options
        )
        try {
            $read.CopyTo($write)
            $write.Flush($true)
        }
        finally {
            $write.Dispose()
        }
    }
    finally {
        $read.Dispose()
    }
}

function Move-PortStationFile {
    param(
        [Parameter(Mandatory)][string]$LiteralPath,
        [Parameter(Mandatory)][string]$Destination
    )
    [System.IO.File]::Move($LiteralPath, $Destination, $true)
}

function Remove-PortStationFile {
    param([Parameter(Mandatory)][string]$LiteralPath)
    Remove-Item -LiteralPath $LiteralPath -Force
}

function Get-PortStationFileHash {
    param([Parameter(Mandatory)][string]$LiteralPath)
    Get-FileHash -Algorithm SHA256 -LiteralPath $LiteralPath
}

function Read-PortStationEfiImageInfo {
    param([Parameter(Mandatory)][System.IO.Stream]$Stream)

    if ($Stream.Length -lt 256) { throw 'Image is too small to be a PE32+ EFI application.' }
    $reader = [System.IO.BinaryReader]::new($Stream)
    try {
            if ($reader.ReadUInt16() -ne 0x5A4D) { throw 'Image is missing the DOS/PE header.' }
            $Stream.Position = 0x3C
            $peOffset = [uint64]$reader.ReadUInt32()
            if ($peOffset -lt 64 -or ($peOffset + 94) -gt [uint64]$Stream.Length) { throw 'Image contains an invalid PE header offset.' }
            $Stream.Position = $peOffset
            if ($reader.ReadUInt32() -ne 0x00004550) { throw 'Image is missing the PE signature.' }
            $machine = $reader.ReadUInt16()
            $Stream.Position = $peOffset + 20
            $optionalHeaderSize = $reader.ReadUInt16()
            $characteristics = $reader.ReadUInt16()
            if ($optionalHeaderSize -lt 70 -or ($peOffset + 24 + $optionalHeaderSize) -gt $Stream.Length) {
                throw 'Image contains an invalid PE optional header.'
            }
            $Stream.Position = $peOffset + 24
            $optionalMagic = $reader.ReadUInt16()
            $Stream.Position = $peOffset + 24 + 68
            $subsystem = $reader.ReadUInt16()
            [pscustomobject]@{
                Length        = $Stream.Length
                Machine       = $machine
                OptionalMagic = $optionalMagic
                Subsystem     = $subsystem
                Characteristics = $characteristics
            }
    }
    finally {
        $reader.Dispose()
    }
}

function Get-PortStationEfiImageInfo {
    param([Parameter(Mandatory)][string]$LiteralPath)

    $stream = [System.IO.File]::Open(
        $LiteralPath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read
    )
    try { Read-PortStationEfiImageInfo -Stream $stream }
    finally { $stream.Dispose() }
}

function Get-PortStationTargetSnapshot {
    param([Parameter(Mandatory)][int]$DiskNumber)

    if ($DiskNumber -eq 0) {
        throw (New-PortStationErrorRecord -Id 'PortStation.TargetRefused' -Message 'Disk 0 is permanently refused.' -TargetObject $DiskNumber)
    }

    $disk = Get-PortStationDisk -Number $DiskNumber
    if (
        $disk.BusType -ne 'USB' -or
        $disk.IsBoot -or
        $disk.IsSystem -or
        $disk.IsOffline -or
        $disk.IsReadOnly -or
        $disk.PartitionStyle -ne 'GPT'
    ) {
        throw (New-PortStationErrorRecord -Id 'PortStation.TargetRefused' -Message "Disk $DiskNumber failed USB/GPT/online/writable/non-system qualification." -TargetObject $disk)
    }

    $fat32 = @(Get-PortStationPartitions -DiskNumber $DiskNumber | ForEach-Object {
        if (-not $_.DriveLetter) { return }
        $volume = Get-PortStationVolume -DriveLetter $_.DriveLetter
        if ($volume.FileSystem -eq 'FAT32') {
            [pscustomobject]@{ Partition = $_; Volume = $volume }
        }
    })

    if ($fat32.Count -ne 1) {
        throw (New-PortStationErrorRecord -Id 'PortStation.TargetRefused' -Message "Expected exactly one mounted FAT32 partition on USB Disk $DiskNumber; found $($fat32.Count)." -TargetObject $fat32)
    }

    $partition = $fat32[0].Partition
    $volume = $fat32[0].Volume
    $diskUniqueId = [string]$disk.UniqueId
    $partitionGuid = [string]$partition.Guid
    $volumeUniqueId = [string]$volume.UniqueId
    if (
        [string]::IsNullOrWhiteSpace($diskUniqueId) -or
        [string]::IsNullOrWhiteSpace($partitionGuid) -or
        $volumeUniqueId -notmatch '^\\\\\?\\Volume\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}\\$'
    ) {
        throw (New-PortStationErrorRecord -Id 'PortStation.TargetRefused' -Message "Disk $DiskNumber did not expose stable disk, partition, and volume identities." -TargetObject $volume)
    }
    [pscustomobject]@{
        DiskNumber      = [int]$disk.Number
        DiskUniqueId    = $diskUniqueId
        DiskSerial      = [string]$disk.SerialNumber
        DiskSize        = [uint64]$disk.Size
        FriendlyName    = [string]$disk.FriendlyName
        PartitionNumber = [int]$partition.PartitionNumber
        PartitionGuid   = $partitionGuid
        PartitionOffset = [uint64]$partition.Offset
        PartitionSize   = [uint64]$partition.Size
        DriveLetter     = [char]$partition.DriveLetter
        VolumeUniqueId  = $volumeUniqueId
    }
}

function Test-PortStationSnapshotMatch {
    param(
        [Parameter(Mandatory)]$Expected,
        [Parameter(Mandatory)]$Actual
    )
    foreach ($property in @(
        'DiskNumber', 'DiskUniqueId', 'DiskSerial', 'DiskSize',
        'PartitionNumber', 'PartitionGuid', 'PartitionOffset', 'PartitionSize',
        'DriveLetter', 'VolumeUniqueId'
    )) {
        if ($Expected.$property -ne $Actual.$property) { return $false }
    }
    return $true
}

function Install-PortStationEfi {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, 255)]
        [int]$DiskNumber,

        [Parameter(Mandatory)]
        [string]$KernelImage
    )

    if ($DiskNumber -eq 0) {
        $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord -Id 'PortStation.TargetRefused' -Message 'Disk 0 is permanently refused.' -TargetObject $DiskNumber))
    }

    try {
        $imageInfo = Get-PortStationEfiImageInfo -LiteralPath $KernelImage
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord -Id 'PortStation.SourceInvalid' -Message $_.Exception.Message -TargetObject $KernelImage))
    }
    if (
        $imageInfo.Machine -ne 0x8664 -or
        $imageInfo.OptionalMagic -ne 0x020B -or
        $imageInfo.Subsystem -ne 10 -or
        ($imageInfo.Characteristics -band 0x0002) -eq 0 -or
        ($imageInfo.Characteristics -band 0x2000) -ne 0
    ) {
        $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord -Id 'PortStation.SourceInvalid' -Message 'Source is not an x86-64 PE32+ EFI application.' -TargetObject $imageInfo))
    }

    $sourceHash = (Get-PortStationFileHash -LiteralPath $KernelImage).Hash
    try {
        $snapshot = Get-PortStationTargetSnapshot -DiskNumber $DiskNumber
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    $drive = "$($snapshot.DriveLetter):"
    $volumeRoot = $snapshot.VolumeUniqueId.TrimEnd('\')
    $destinationDirectory = "$volumeRoot\EFI\BOOT"
    $destination = "$destinationDirectory\BOOTX64.EFI"
    $staged = "$destinationDirectory\.BOOTX64.EFI.portstation.new"
    $backup = "$destinationDirectory\.BOOTX64.EFI.portstation.previous"
    $displayDestination = "$drive\EFI\BOOT\BOOTX64.EFI"
    $description = "USB Disk $DiskNumber ($($snapshot.FriendlyName), $([math]::Round($snapshot.DiskSize / 1GB, 2)) GB)"

    Write-Host "Qualified target: $description"
    Write-Host "Source image:    $KernelImage"
    Write-Host "Destination:     $displayDestination"
    Write-Host 'No formatting, repartitioning, or boot-order changes will be performed.'

    if (-not $PSCmdlet.ShouldProcess($description, "Stage, transactionally install, and verify $displayDestination")) { return }

    try {
        $current = Get-PortStationTargetSnapshot -DiskNumber $DiskNumber
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    if (-not (Test-PortStationSnapshotMatch -Expected $snapshot -Actual $current)) {
        $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord -Id 'PortStation.TargetChanged' -Message 'Target identity changed after qualification.' -TargetObject $current))
    }
    if ((Get-PortStationFileHash -LiteralPath $KernelImage).Hash -ne $sourceHash) {
        $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord -Id 'PortStation.SourceChanged' -Message 'Source image changed after qualification.' -TargetObject $KernelImage))
    }

    New-PortStationDirectory -Path $destinationDirectory
    if (Test-PortStationPath -LiteralPath $staged) { Remove-PortStationFile -LiteralPath $staged }
    if (Test-PortStationPath -LiteralPath $backup) { Remove-PortStationFile -LiteralPath $backup }

    try {
        Copy-PortStationFile -LiteralPath $KernelImage -Destination $staged
        if ((Get-PortStationFileHash -LiteralPath $staged).Hash -ne $sourceHash) {
            throw 'Staged SHA-256 verification failed; live boot image was not replaced.'
        }
    }
    catch {
        if (Test-PortStationPath -LiteralPath $staged) { Remove-PortStationFile -LiteralPath $staged }
        $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord -Id 'PortStation.HashMismatch' -Message $_.Exception.Message -TargetObject $staged))
    }

    $hadDestination = Test-PortStationPath -LiteralPath $destination
    $previousHash = $null
    if ($hadDestination) {
        $previousHash = (Get-PortStationFileHash -LiteralPath $destination).Hash
        try {
            Copy-PortStationFile -LiteralPath $destination -Destination $backup
            if ((Get-PortStationFileHash -LiteralPath $backup).Hash -ne $previousHash) {
                throw 'Rollback copy SHA-256 verification failed; live boot image was not replaced.'
            }
        }
        catch {
            if (Test-PortStationPath -LiteralPath $backup) { Remove-PortStationFile -LiteralPath $backup }
            if (Test-PortStationPath -LiteralPath $staged) { Remove-PortStationFile -LiteralPath $staged }
            $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord -Id 'PortStation.HashMismatch' -Message $_.Exception.Message -TargetObject $backup))
        }
    }

    try {
        Move-PortStationFile -LiteralPath $staged -Destination $destination
        $destinationHash = (Get-PortStationFileHash -LiteralPath $destination).Hash
        if ($destinationHash -ne $sourceHash) { throw 'Installed SHA-256 verification failed.' }
    }
    catch {
        $installFailure = $_.Exception.Message
        try {
            if ($hadDestination -and (Test-PortStationPath -LiteralPath $backup)) {
                Move-PortStationFile -LiteralPath $backup -Destination $destination
                if ((Get-PortStationFileHash -LiteralPath $destination).Hash -ne $previousHash) {
                    throw 'Restored boot image failed SHA-256 verification.'
                }
            }
            elseif (Test-PortStationPath -LiteralPath $destination) {
                Remove-PortStationFile -LiteralPath $destination
            }
        }
        catch {
            $rollbackFailure = $_.Exception.Message
            $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord -Id 'PortStation.RollbackFailed' -Message "$installFailure Rollback failed: $rollbackFailure" -TargetObject $destination))
        }
        finally {
            if (Test-PortStationPath -LiteralPath $staged) { Remove-PortStationFile -LiteralPath $staged }
        }
        $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord -Id 'PortStation.InstallFailed' -Message $installFailure -TargetObject $destination))
    }

    if (Test-PortStationPath -LiteralPath $backup) { Remove-PortStationFile -LiteralPath $backup }

    [pscustomobject]@{
        DiskNumber  = $DiskNumber
        Device      = $snapshot.FriendlyName
        Destination = $destination
        SHA256      = $destinationHash.ToLowerInvariant()
        Verified    = $true
    }
}

Export-ModuleMember -Function Install-PortStationEfi
