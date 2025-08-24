<#
.SYNOPSIS
Enables unconstrained delegation for a specified Active Directory user.

.DESCRIPTION
This script sets the "Trusted for Delegation" flag on a user account.  
Once enabled, the user can impersonate other users—including high-privileged accounts—  
after they authenticate to a service hosted by this account.  
Also known as Delegation Abuse, this is commonly leveraged in post-exploitation or lab environments.

.REQUIREMENTS
- Permissions to modify the target user’s account.
- Domain-joined machine with the ActiveDirectory PowerShell module (RSAT tools).

.PARAMETER UserIdentity
The AD user to modify (e.g., "target.user").  
If the user does not exist, the script will create a new account with a default password 
(P@ssw0rd123!) and enable it.

.EXAMPLE
PS> .\enable_unconstrained_delegation.ps1 -UserIdentity "target.user"
Enables unconstrained delegation for "target.user".

.NOTES
Author: Phoenix (example)  
Use only in lab or test environments.
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$UserIdentity
)

# Ensure the AD module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory))
{
	Write-Error "ActiveDirectory module not found. Please install RSAT tools."
	exit
}
Import-Module ActiveDirectory

$user = Get-ADUser -Identity $UserIdentity -Properties userAccountControl -ErrorAction SilentlyContinue
if (-not $user)
{
	Write-Host "User '$UserIdentity' not found. Creating new user..."
	# Adjust these parameters as needed for your environment
	New-ADUser -Name $UserIdentity `
		-SamAccountName $UserIdentity `
		-AccountPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
		-Enabled $true `
		-PasswordNeverExpires $true
	# Optionally, re-fetch the user object
	$user = Get-ADUser -Identity $UserIdentity -Properties userAccountControl
}

Set-ADAccountControl -Identity $UserIdentity -TrustedForDelegation $true
