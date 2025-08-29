<#
.SYNOPSIS
    Configures constrained delegation for specified Active Directory computer accounts.

.DESCRIPTION
    This script adds ServicePrincipalNames (SPNs) and allowed delegation targets (msDS-AllowedToDelegateTo)
    to one or more computer accounts dynamically. It verifies that the changes were applied and exits
    with code 1 if any update fails.

.PARAMETER ComputerName
    The name of the computer account to update (e.g., 'castelblack$').

.PARAMETER SPNs
    An array of ServicePrincipalNames to add to the computer account
    (e.g., @('HTTP/winterfell.north.sevenkingdoms.local')).

.PARAMETER AllowedDelegationTargets
    An array of SPNs for msDS-AllowedToDelegateTo
    (e.g., @('HTTP/winterfell.north.sevenkingdoms.local','HTTP/winterfell')).

.EXAMPLE
    PS> .\Set-ConstrainedDelegation.ps1 -ComputerName "castelblack$" `
          -SPNs @("HTTP/winterfell.north.sevenkingdoms.local") `
          -AllowedDelegationTargets @("HTTP/winterfell.north.sevenkingdoms.local","HTTP/winterfell")

.NOTES
    Author: phoenix
    Requires: ActiveDirectory module
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$ComputerName,

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
	# Check if computer exists
	$adComputer = Get-ADComputer -Identity $ComputerName -ErrorAction Stop
	Write-Host "[*] Processing computer: $ComputerName" -ForegroundColor Cyan

	# Add SPNs if provided
	if ($SPNs.Count -gt 0)
	{
		Set-ADComputer -Identity $ComputerName -ServicePrincipalNames @{Add=$SPNs}
		Write-Host "[+] Added SPNs: $($SPNs -join ', ')" -ForegroundColor Green
	}

	# Add allowed delegation targets if provided
	if ($AllowedDelegationTargets.Count -gt 0)
	{
		Set-ADComputer -Identity $ComputerName -Add @{ 'msDS-AllowedToDelegateTo' = $AllowedDelegationTargets }
		Write-Host "[+] Added allowed delegation targets: $($AllowedDelegationTargets -join ', ')" -ForegroundColor Green
	}

} catch
{
	Write-Error "[!] Failed to update computer '$ComputerName': $_"
	exit 1
}

# Verification
try
{
	$adComputer = Get-ADComputer -Identity $ComputerName -Properties ServicePrincipalNames, msDS-AllowedToDelegateTo
	$spnCheck = $SPNs | Where-Object { $_ -notin $adComputer.ServicePrincipalNames }
	$targetCheck = $AllowedDelegationTargets | Where-Object { $_ -notin $adComputer.'msDS-AllowedToDelegateTo' }

	if ($spnCheck.Count -gt 0 -or $targetCheck.Count -gt 0)
	{
		Write-Error "[!] Verification failed for $ComputerName."
		exit 1
	} else
	{
		Write-Host "[+] Delegation configuration verified for $ComputerName." -ForegroundColor Green
		exit 0
	}
} catch
{
	Write-Error "[!] Verification error for ${ComputerName}: $_"
	exit 1
}
