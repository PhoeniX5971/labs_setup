<#
.SYNOPSIS
    Enables LLMNR (Link-Local Multicast Name Resolution) on the local machine via registry.

.DESCRIPTION
    This script sets the registry value 'EnableMulticast' to 1 under
    HKLM\Software\Policies\Microsoft\Windows NT\DNSClient to enable LLMNR.
    It verifies that the change was applied successfully and exits with code 1 if it fails.

.PARAMETER Enable
    Value to set (0 = disable, 1 = enable). Default is 1.

.EXAMPLE
    PS> .\Enable-LLMNR.ps1 -Enable 1

.NOTES
    Author: phoenix
#>

param(
	[Parameter(Mandatory=$false)]
	[ValidateSet(0,1)]
	[int]$Enable = 1
)

$regPath = "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient"
$regName = "EnableMulticast"

try
{
	Write-Host "[*] Setting LLMNR to '$Enable'..." -ForegroundColor Cyan
	# Create key if it doesn't exist
	if (-not (Test-Path $regPath))
	{
		New-Item -Path $regPath -Force | Out-Null
		Write-Host "[*] Registry key created: $regPath" -ForegroundColor Cyan
	}

	# Set value
	Set-ItemProperty -Path $regPath -Name $regName -Value $Enable -Type DWord
	Write-Host "[+] LLMNR registry value set." -ForegroundColor Green

	# Verification
	$currentValue = Get-ItemProperty -Path $regPath -Name $regName
	if ($currentValue.$regName -eq $Enable)
	{
		Write-Host "[+] Verification passed: EnableMulticast = $($currentValue.$regName)" -ForegroundColor Green
		exit 0
	} else
	{
		Write-Error "[!] Verification failed: EnableMulticast = $($currentValue.$regName)"
		exit 1
	}

} catch
{
	Write-Error "[!] Failed to set EnableMulticast: $_"
	exit 1
}
