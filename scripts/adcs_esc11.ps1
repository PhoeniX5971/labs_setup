##################################################
#  ESC11: DISABLE ENCRYPTED CERT REQ ENFORCEMENT #
##################################################
# Makes the CA vulnerable by disabling enforcement of encrypted
# certificate requests. Required for ESC11 abuse.

# Requires:
# - Admin privileges on the CA server
# - PowerShell running elevated
#
# This sets the flag 'IF_ENFORCEENCRYPTICERTREQUEST' on the CA to allow
# unencrypted certificate requests, enabling impersonation attacks.

# Check if Certificate Services (certsvc) is installed
Write-Host "[*] Checking if Certificate Services (certsvc) is installed..."
$certsvc = Get-Service -Name certsvc -ErrorAction SilentlyContinue

if (-not $certsvc) {
    Write-Warning "[!] Certificate Services not found. Installing ADCS Certification Authority..."

    # Install ADCS role with management tools
    Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools

    # Configure a default Enterprise Root CA (for lab purposes)
    Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -Force

    # Refresh the service object
    Start-Sleep -Seconds 5
    $certsvc = Get-Service -Name certsvc -ErrorAction SilentlyContinue

    if (-not $certsvc) {
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
