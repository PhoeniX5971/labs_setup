<#
.SYNOPSIS
    Marks specified Active Directory accounts as "sensitive and cannot be delegated".

.DESCRIPTION
    This script sets the 'AccountNotDelegated' flag to $true for each account in the provided list.
    Accounts marked as sensitive cannot be used in Kerberos delegation scenarios,
    protecting them from delegation-based attacks.

.PARAMETER Accounts
    An array of Active Directory account names (sAMAccountName or distinguishedName).

.EXAMPLE
    PS> .\Set-SensitiveAccounts.ps1 -Accounts @("Administrator","SQLService")

.NOTES
    Author: phoenix
    Requires: ActiveDirectory module (Import-Module ActiveDirectory)
#>

param(
	[Parameter(Mandatory = $true)]
	[string[]]$Accounts
)

# Import AD module if not already imported
if (-not (Get-Module -ListAvailable -Name ActiveDirectory))
{
	Write-Error "ActiveDirectory module not found. Install RSAT or run on a Domain Controller."
	exit 1
} else
{
	Import-Module ActiveDirectory
}

$failedAccounts = @()

foreach ($account in $Accounts)
{
	try
	{
		# Check if the account exists in AD
		$adUser = Get-ADUser -Identity $account -ErrorAction Stop
		Write-Host "[*] Processing account: $account" -ForegroundColor Cyan

		# Set AccountNotDelegated flag to true
		Set-ADUser -Identity $account -AccountNotDelegated $true
		Write-Host "[+] $account is now marked as sensitive (cannot be delegated)." -ForegroundColor Green

	} catch
	{
		Write-Warning "[!] Account '$account' not found or could not be updated."
		$failedAccounts += $account
	}
}

# Verification step
$verifyFailures = @()
foreach ($account in $Accounts)
{
	try
	{
		$adUser = Get-ADUser -Identity $account -Properties AccountNotDelegated
		if (-not $adUser.AccountNotDelegated)
		{
			$verifyFailures += $account
		}
	} catch
	{
		$verifyFailures += $account
	}
}

if ($verifyFailures.Count -gt 0)
{
	Write-Error "[!] The following accounts failed verification: $($verifyFailures -join ', ')"
	exit 1
} else
{
	Write-Host "[+] All accounts successfully marked as sensitive." -ForegroundColor Green
	exit 0
}
