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

# Check if Certificate Services (certsvc) is installed
Write-Host "[*] Checking if Certificate Services (certsvc) is installed..."
$certsvc = Get-Service -Name certsvc -ErrorAction SilentlyContinue

if (-not $certsvc)
{
	Write-Warning "[!] Certificate Services not found. Installing ADCS Certification Authority..."

	# Install ADCS role with management tools
	Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools

	# Configure a default Enterprise Root CA (for lab purposes)
	Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -Force

	# Refresh the service object
	Start-Sleep -Seconds 5
	$certsvc = Get-Service -Name certsvc -ErrorAction SilentlyContinue

	if (-not $certsvc)
	{
		Write-Error "[-] Failed to install or detect certsvc. Aborting setup."
		exit 1
	}

	Write-Host "[+] ADCS Certification Authority installed successfully."
}

# Set the CA flag to make it vulnerable (ESC11)
Write-Host "[*] Setting IF_ENFORCEENCRYPTICERTREQUEST flag..."
certutil.exe -setreg CA\InterfaceFlags -IF_ENFORCEENCRYPTICERTREQUEST

# Restart Certificate Services to apply change
Write-Host "[*] Restarting Certificate Services..."
Restart-Service -Name certsvc -Force

Write-Host "[+] ESC11 setup complete. CA is now vulnerable to unencrypted cert requests."
