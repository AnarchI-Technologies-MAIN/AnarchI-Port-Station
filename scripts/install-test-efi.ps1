[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateRange(0, 255)]
    [int]$DiskNumber,

    [Parameter(Mandatory)]
    [string]$KernelImage
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'PortStation.Install.psm1'
Import-Module $modulePath -Force

Install-PortStationEfi @PSBoundParameters
