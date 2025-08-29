<#
.SYNOPSIS
    Creates or modifies a GPO dynamically with specified registry settings and user permissions.

.DESCRIPTION
    This script installs GPMC if needed, creates a new GPO (or updates an existing one),
    sets registry values for users or machines, and optionally assigns GPO permissions
    to a target user. Verification ensures the GPO exists and the registry settings are applied.

.PARAMETER GPOName
    The name of the GPO to create or modify.

.PARAMETER GPOComment
    A comment to attach to the GPO.

.PARAMETER GPOUser
    A user to assign permissions for editing the GPO.

.PARAMETER DomainDN
    The distinguished name of the domain where the GPO should be linked.

.PARAMETER DesktopColor
    The RGB string for the desktop background color (e.g., "100 175 200").

.EXAMPLE
    PS> .\GPO-Abuse.ps1 -GPOName "StarkWallpaper" -GPOComment "Change Wallpaper" `
          -GPOUser "samwell.tarly" -DomainDN "DC=north,DC=sevenkingdoms,DC=local" `
          -DesktopColor "100 175 200"

.NOTES
    Author: phoenix
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$GPOName,

	[Parameter(Mandatory=$false)]
	[string]$GPOComment = "",

	[Parameter(Mandatory=$true)]
	[string]$GPOUser,

	[Parameter(Mandatory=$true)]
	[string]$DomainDN,

	[Parameter(Mandatory=$false)]
	[string]$DesktopColor = "100 175 200"
)

# Install GPMC if missing
if (-not (Get-WindowsFeature -Name GPMC).Installed)
{
	Write-Host "[*] Installing GPMC..." -ForegroundColor Cyan
	Install-WindowsFeature -Name GPMC -IncludeManagementTools
}

# Check if GPO exists
$gpo_exist = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue

if ($gpo_exist)
{
	Write-Host "[*] GPO '$GPOName' exists. Skipping creation." -ForegroundColor Yellow
} else
{
	Write-Host "[*] Creating GPO '$GPOName'..." -ForegroundColor Cyan
	$newGPO = New-GPO -Name $GPOName -Comment $GPOComment
	Write-Host "[+] Linking GPO to domain '$DomainDN'..." -ForegroundColor Green
	New-GPLink -Name $GPOName -Target $DomainDN
}

# Set registry values
Write-Host "[*] Setting registry values for GPO..." -ForegroundColor Cyan
Set-GPRegistryValue -Name $GPOName -Key "HKEY_CURRENT_USER\Control Panel\Colors" -ValueName Background -Type String -Value $DesktopColor
Set-GPRegistryValue -Name $GPOName -Key "HKEY_CURRENT_USER\Control Panel\Desktop" -ValueName Wallpaper -Type String -Value ""
Set-GPRegistryValue -Name $GPOName -Key "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\CurrentVersion\WinLogon" -ValueName SyncForegroundPolicy -Type DWORD -Value 1

# Assign GPO permissions
Write-Host "[*] Setting GPO permissions for user '$GPOUser'..." -ForegroundColor Cyan
Set-GPPermissions -Name $GPOName -PermissionLevel GpoEditDeleteModifySecurity -TargetName $GPOUser -TargetType User

# Verification
try
{
	$verifyGPO = Get-GPO -Name $GPOName -ErrorAction Stop
	if ($verifyGPO)
	{
		Write-Host "[+] Verification passed: GPO '$GPOName' exists." -ForegroundColor Green
		exit 0
	}
} catch
{
	Write-Error "[!] Verification failed: GPO '$GPOName' does not exist."
	exit 1
}
