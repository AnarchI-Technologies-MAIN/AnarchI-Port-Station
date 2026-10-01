[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateRange(1, 255)]
    [int]$DiskNumber,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$KernelImage
)

$ErrorActionPreference = 'Stop'

if ($DiskNumber -eq 0) {
    throw 'Disk 0 is permanently refused.'
}

$disk = Get-Disk -Number $DiskNumber
if ($disk.BusType -ne 'USB') {
    throw "Disk $DiskNumber is not reported as USB. Refusing."
}

if ($disk.IsBoot -or $disk.IsSystem) {
    throw "Disk $DiskNumber is a boot/system disk. Refusing."
}

$fat32 = @(Get-Partition -DiskNumber $DiskNumber | Where-Object {
    $_.DriveLetter -and (Get-Volume -DriveLetter $_.DriveLetter).FileSystem -eq 'FAT32'
})

if ($fat32.Count -ne 1) {
    throw "Expected exactly one mounted FAT32 partition on USB Disk $DiskNumber; found $($fat32.Count)."
}

$drive = "$($fat32[0].DriveLetter):"
$destination = Join-Path $drive 'EFI\BOOT\BOOTX64.EFI'
$description = "USB Disk $DiskNumber ($($disk.FriendlyName), $([math]::Round($disk.Size / 1GB, 2)) GB)"

Write-Host "Qualified target: $description"
Write-Host "Source image:    $KernelImage"
Write-Host "Destination:     $destination"
Write-Host 'No formatting, repartitioning, or boot-order changes will be performed.'

if (-not $PSCmdlet.ShouldProcess($description, "Install and verify $destination")) {
    return
}

New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
Copy-Item -LiteralPath $KernelImage -Destination $destination -Force

$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $KernelImage).Hash
$destinationHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destination).Hash

if ($sourceHash -ne $destinationHash) {
    throw 'SHA-256 read-back verification failed.'
}

[pscustomobject]@{
    DiskNumber = $DiskNumber
    Device     = $disk.FriendlyName
    Destination = $destination
    SHA256     = $destinationHash.ToLowerInvariant()
    Verified   = $true
}
