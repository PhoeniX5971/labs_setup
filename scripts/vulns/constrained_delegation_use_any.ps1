<#
.SYNOPSIS
    Configures delegation for specified Active Directory user accounts.

.DESCRIPTION
    This script dynamically adds ServicePrincipalNames (SPNs), sets the user as
    trusted for delegation, and configures msDS-AllowedToDelegateTo for a user account.
    It verifies the configuration and exits with code 1 if any part fails.

.PARAMETER UserName
    The sAMAccountName or distinguishedName of the user account to configure.

.PARAMETER SPNs
    An array of ServicePrincipalNames to add to the user account
    (e.g., @('CIFS/thewall.north.sevenkingdoms.local')).

.PARAMETER AllowedDelegationTargets
    An array of SPNs for msDS-AllowedToDelegateTo
    (e.g., @('CIFS/winterfell.north.sevenkingdoms.local','CIFS/winterfell')).

.EXAMPLE
    PS> .\Set-UserDelegation.ps1 -UserName "jon.snow" `
          -SPNs @("CIFS/thewall.north.sevenkingdoms.local") `
          -AllowedDelegationTargets @("CIFS/winterfell.north.sevenkingdoms.local","CIFS/winterfell")

.NOTES
    Author: phoenix
    Requires: ActiveDirectory module
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$UserName,

	[Parameter(Mandatory=$false)]
	[string[]]$SPNs = @(),

	[Parameter(Mandatory=$false)]
	[string[]]$AllowedDelegationTargets = @()
)

# Import AD module
if (-not (Get-Module -ListAvailable -Name ActiveDirectory))
{
	Write-Error "ActiveDirectory module not found. Install RSAT or run on a Domain Controller."
	exit 1
} else
{
	Import-Module ActiveDirectory
}

try
{
	# Check if user exists
	$adUser = Get-ADUser -Identity $UserName -ErrorAction Stop
	Write-Host "[*] Processing user: $UserName" -ForegroundColor Cyan

	# Add SPNs if provided
	if ($SPNs.Count -gt 0)
	{
		Set-ADUser -Identity $UserName -ServicePrincipalNames @{Add=$SPNs}
		Write-Host "[+] Added SPNs: $($SPNs -join ', ')" -ForegroundColor Green
	}

	# Set user as trusted for delegation
	Set-ADAccountControl -Identity $UserName -TrustedToAuthForDelegation $true
	Write-Host "[+] User set as trusted for delegation" -ForegroundColor Green

	# Add allowed delegation targets if provided
	if ($AllowedDelegationTargets.Count -gt 0)
	{
		Set-ADUser -Identity $UserName -Add @{ 'msDS-AllowedToDelegateTo' = $AllowedDelegationTargets }
		Write-Host "[+] Added allowed delegation targets: $($AllowedDelegationTargets -join ', ')" -ForegroundColor Green
	}

} catch
{
	Write-Error "[!] Failed to update user '$UserName': $_"
	exit 1
}

# Verification
try
{
	$adUser = Get-ADUser -Identity $UserName -Properties ServicePrincipalNames, msDS-AllowedToDelegateTo, TrustedForDelegation
	$spnCheck = $SPNs | Where-Object { $_ -notin $adUser.ServicePrincipalNames }
	$targetCheck = $AllowedDelegationTargets | Where-Object { $_ -notin $adUser.'msDS-AllowedToDelegateTo' }
	$delegationCheck = -not $adUser.TrustedForDelegation

	if ($spnCheck.Count -gt 0 -or $targetCheck.Count -gt 0 -or $delegationCheck)
	{
		Write-Error "[!] Verification failed for $UserName."
		exit 1
	} else
	{
		Write-Host "[+] User delegation configuration verified for $UserName." -ForegroundColor Green
		exit 0
	}
} catch
{
	Write-Error "[!] Verification error for ${UserName}: $_"
	exit 1
}
