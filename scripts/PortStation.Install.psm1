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

function Test-PortStationSourceFile {
    param([Parameter(Mandatory)][string]$LiteralPath)
    Test-Path -LiteralPath $LiteralPath -PathType Leaf
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

function New-PortStationDirectory {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Copy-PortStationFile {
    param(
        [Parameter(Mandatory)][string]$LiteralPath,
        [Parameter(Mandatory)][string]$Destination
    )
    Copy-Item -LiteralPath $LiteralPath -Destination $Destination -Force
}

function Get-PortStationFileHash {
    param([Parameter(Mandatory)][string]$LiteralPath)
    Get-FileHash -Algorithm SHA256 -LiteralPath $LiteralPath
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
        $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord `
            -Id 'PortStation.TargetRefused' `
            -Message 'Disk 0 is permanently refused.' `
            -TargetObject $DiskNumber))
    }

    if (-not (Test-PortStationSourceFile -LiteralPath $KernelImage)) {
        throw "Kernel image does not exist: $KernelImage"
    }

    $disk = Get-PortStationDisk -Number $DiskNumber
    if ($disk.BusType -ne 'USB') {
        $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord `
            -Id 'PortStation.TargetRefused' `
            -Message "Disk $DiskNumber is not reported as USB. Refusing." `
            -TargetObject $disk))
    }

    if ($disk.IsBoot -or $disk.IsSystem) {
        $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord `
            -Id 'PortStation.TargetRefused' `
            -Message "Disk $DiskNumber is a boot/system disk. Refusing." `
            -TargetObject $disk))
    }

    $fat32 = @(Get-PortStationPartitions -DiskNumber $DiskNumber | Where-Object {
        $_.DriveLetter -and (Get-PortStationVolume -DriveLetter $_.DriveLetter).FileSystem -eq 'FAT32'
    })

    if ($fat32.Count -ne 1) {
        $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord `
            -Id 'PortStation.TargetRefused' `
            -Message "Expected exactly one mounted FAT32 partition on USB Disk $DiskNumber; found $($fat32.Count)." `
            -TargetObject $fat32))
    }

    $drive = "$($fat32[0].DriveLetter):"
    $destinationDirectory = "$drive\EFI\BOOT"
    $destination = "$destinationDirectory\BOOTX64.EFI"
    $description = "USB Disk $DiskNumber ($($disk.FriendlyName), $([math]::Round($disk.Size / 1GB, 2)) GB)"

    Write-Host "Qualified target: $description"
    Write-Host "Source image:    $KernelImage"
    Write-Host "Destination:     $destination"
    Write-Host 'No formatting, repartitioning, or boot-order changes will be performed.'

    if (-not $PSCmdlet.ShouldProcess($description, "Install and verify $destination")) {
        return
    }

    New-PortStationDirectory -Path $destinationDirectory
    Copy-PortStationFile -LiteralPath $KernelImage -Destination $destination

    $sourceHash = (Get-PortStationFileHash -LiteralPath $KernelImage).Hash
    $destinationHash = (Get-PortStationFileHash -LiteralPath $destination).Hash

    if ($sourceHash -ne $destinationHash) {
        $PSCmdlet.ThrowTerminatingError((New-PortStationErrorRecord `
            -Id 'PortStation.HashMismatch' `
            -Message 'SHA-256 read-back verification failed.' `
            -TargetObject $destination))
    }

    [pscustomobject]@{
        DiskNumber  = $DiskNumber
        Device      = $disk.FriendlyName
        Destination = $destination
        SHA256      = $destinationHash.ToLowerInvariant()
        Verified    = $true
    }
}

Export-ModuleMember -Function Install-PortStationEfi
