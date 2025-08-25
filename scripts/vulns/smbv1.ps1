<#
.SYNOPSIS
Enables the SMBv1 protocol on the target system.

.DESCRIPTION
This script checks whether the SMB1Protocol Windows optional feature is installed and enabled.  
If it is not enabled, the script will enable it.  
SMBv1 is an outdated and insecure protocol, vulnerable to multiple attacks such as EternalBlue and WannaCry.  
This script should only be used in lab or testing environments.

The script will trigger a reboot if required or if the system is a Windows Server edition.

.EXAMPLE
PS> .\enable_smbv1.ps1
Checks the SMB1Protocol feature and enables it if necessary, rebooting the system only if required.

.NOTES
Author: Phoenix (example)  
SMBv1 should never be enabled on production systems due to security risks.
#>

# Check if SMB1Protocol is installed
$feature = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol

if ($feature.State -ne 'Enabled')
{
	Write-Host "[*] Enabling SMB1Protocol..." -ForegroundColor Cyan
	Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -All -NoRestart

	# Re-fetch the feature status
	$feature = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol

	# Check if a reboot is needed or if it's a Server edition
	if ($feature.RestartNeeded -or ((Get-ComputerInfo).WindowsProductName -like '*Server*'))
	{
		Write-Host "[!] Reboot is required. Please Restart..." -ForegroundColor Yellow
		exit 0  # script exits here due to reboot
	} elseif ($feature.State -eq 'Enabled')
	{
		Write-Host "[SUCCESS] SMB1Protocol enabled. No reboot required." -ForegroundColor Green
		exit 0
	} else
	{
		Write-Host "[FAIL] Failed to enable SMB1Protocol." -ForegroundColor Red
		exit 1
	}
} else
{
	Write-Host "[+] SMB1Protocol is already enabled." -ForegroundColor Green
	exit 0
}
