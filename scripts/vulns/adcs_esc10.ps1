#############################################
#  WEAKEN CERTIFICATE BINDING ENFORCEMENT   #
#############################################
# Requires:
# - Domain Controller or system with KDC role
# - Admin privileges (run as Administrator)
#
# This script configures two registry keys to weaken certificate-based
# authentication enforcement in Active Directory.
#
# SET 1: Disables StrongCertificateBindingEnforcement to allow loose
# certificate-to-account mapping by the KDC.
#
# SET 2: Forces UPN-only certificate mapping via Schannel, making it
# easier to spoof or abuse in ADCS attacks (e.g., ESC1, ESC8).
#
# These changes are often used in lab environments to simulate
# vulnerable ADCS configurations for tools like Certipy.
#
# Usage:
# .\enable_adcs_weak_mapping.ps1

#############################################
#  SET 1: DISABLE STRONG CERT BINDING (KDC) #
#############################################

# Define the registry path and key for StrongCertificateBindingEnforcement
$kdcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Kdc"
$kdcName = "StrongCertificateBindingEnforcement"
$kdcValue = 0  # Disables strong binding enforcement

# Check if the registry key exists
$currentKdcValue = Get-ItemProperty -Path $kdcPath -Name $kdcName -ErrorAction SilentlyContinue

# If it doesn't exist, create it
if ($null -eq $currentKdcValue) {
    Write-Host "[*] KDC key doesn't exist. Creating..."
    New-ItemProperty -Path $kdcPath -Name $kdcName -PropertyType DWORD -Value $kdcValue -Force
} else {
    # If it does exist, overwrite it with the weaker setting
    Write-Host "[*] KDC key exists. Setting to 0..."
    Set-ItemProperty -Path $kdcPath -Name $kdcName -Value $kdcValue
}

# Confirm the value was set
$newKdcValue = Get-ItemProperty -Path $kdcPath -Name $kdcName
Write-Host "[+] New KDC Value: $($newKdcValue.$kdcName)"

########################################################
#  SET 2: ENABLE UPN-ONLY MAPPING (SCHANNEL REGISTRY)  #
########################################################

# Define the registry path and key for CertificateMappingMethods
$schannelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\Schannel"
$certMapName = "CertificateMappingMethods"
$certMapValue = 0x4  # UPN-only mapping method

# Check if the registry key exists
$currentCertMap = Get-ItemProperty -Path $schannelPath -Name $certMapName -ErrorAction SilentlyContinue

# If it doesn't exist, create it
if ($null -eq $currentCertMap) {
    Write-Host "[*] Schannel key doesn't exist. Creating..."
    New-ItemProperty -Path $schannelPath -Name $certMapName -PropertyType DWORD -Value $certMapValue -Force
} else {
    # If it does exist, set it to 0x4
    Write-Host "[*] Schannel key exists. Setting to 0x4..."
    Set-ItemProperty -Path $schannelPath -Name $certMapName -Value $certMapValue
}

# Confirm the value was set
$newCertMapValue = Get-ItemProperty -Path $schannelPath -Name $certMapName
Write-Host "[+] New CertificateMappingMethods Value: $($newCertMapValue.$certMapName)"
