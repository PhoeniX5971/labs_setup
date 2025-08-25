<#
.SYNOPSIS
Disables enforcement of encrypted certificate requests on a Certification Authority (ESC11).

.DESCRIPTION
This script makes a CA vulnerable by disabling enforcement of encrypted certificate requests.  
It sets the `IF_ENFORCEENCRYPTICERTREQUEST` flag on the CA, which allows unencrypted requests.  
This misconfiguration enables impersonation attacks and is commonly referred to as ESC11.

If the CA service is not installed, the script installs and configures a default Enterprise Root CA 
(for lab/testing purposes).

.REQUIREMENTS
- Must be run with Administrator privileges on the CA server.
- PowerShell must be running elevated.

.EXAMPLE
PS> .\enable_ESC11.ps1
Disables encrypted certificate request enforcement and makes the CA vulnerable to ESC11.

.NOTES
Author: Phoenix (example)
Attack Reference: ESC11 – Encrypted Certificate Request Enforcement
Intended for lab and educational use only.
#>

##################################################
#  ESC11: DISABLE ENCRYPTED CERT REQ ENFORCEMENT #
##################################################

Write-Host "[*] Checking if Certificate Services (certsvc) is installed..." -ForegroundColor Cyan
$certsvc = Get-Service -Name certsvc -ErrorAction SilentlyContinue

if (-not $certsvc)
{
	Write-Warning "[!] Certificate Services not found. Installing ADCS Certification Authority..."

	Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools
	Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -Force

	Start-Sleep -Seconds 5
	$certsvc = Get-Service -Name certsvc -ErrorAction SilentlyContinue

	if (-not $certsvc)
	{
		Write-Host "[-] Failed to install or detect certsvc. Aborting setup." -ForegroundColor Red
		exit 1
	}

	Write-Host "[+] ADCS Certification Authority installed successfully." -ForegroundColor Green
}

Write-Host "[*] Setting IF_ENFORCEENCRYPTICERTREQUEST flag..." -ForegroundColor Cyan
certutil.exe -setreg CA\InterfaceFlags -IF_ENFORCEENCRYPTICERTREQUEST

Write-Host "[*] Restarting Certificate Services..." -ForegroundColor Cyan
Restart-Service -Name certsvc -Force

Write-Host "[+] ESC11 setup complete. CA is now vulnerable to unencrypted cert requests." -ForegroundColor Green

##################################################
#  CHECKER: VERIFY FLAG AND EXIT CODE           #
##################################################

# Get the current InterfaceFlags value
$caName = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration").PSChildName
$flagsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\$caName"
$interfaceFlags = (Get-ItemProperty -Path $flagsPath -Name InterfaceFlags -ErrorAction SilentlyContinue).InterfaceFlags

# IF_ENFORCEENCRYPTICERTREQUEST = 0x200 (512)
$flagCleared = ($interfaceFlags -band 0x200) -eq 0

if ($flagCleared)
{
	Write-Host "[SUCCESS] IF_ENFORCEENCRYPTICERTREQUEST flag disabled correctly. ESC11 applied!" -ForegroundColor Green
	exit 0
} else
{
	Write-Host "[FAIL] IF_ENFORCEENCRYPTICERTREQUEST flag still set! ESC11 failed!" -ForegroundColor Red
	exit 1
}
