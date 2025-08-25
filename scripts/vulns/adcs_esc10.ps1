<#
.SYNOPSIS
Weakens certificate binding enforcement in Active Directory for testing and lab purposes.

.DESCRIPTION
This script configures two registry keys that affect certificate-based authentication in AD:
1. Disables StrongCertificateBindingEnforcement in the KDC service, allowing loose certificate-to-account mapping.
2. Forces Schannel to use UPN-only certificate mapping, which can be abused in ADCS attacks (e.g., ESC1, ESC8).

These changes reduce security and are typically only used in lab environments 
to simulate vulnerable Active Directory Certificate Services (ADCS) configurations 
for tools like Certipy.

.REQUIREMENTS
- Must be run on a Domain Controller or a system with the KDC role.
- Administrator privileges (Run as Administrator).

.EXAMPLE
PS> .\enable_adcs_weak_mapping.ps1
Configures registry keys to weaken ADCS certificate enforcement.

.NOTES
Author: Phoenix (example)
This script is for educational and lab use only. Do not run in production.
#>

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
if ($null -eq $currentKdcValue)
{
	Write-Host "[*] KDC key doesn't exist. Creating..."
	New-ItemProperty -Path $kdcPath -Name $kdcName -PropertyType DWORD -Value $kdcValue -Force
} else
{
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
if ($null -eq $currentCertMap)
{
	Write-Host "[*] Schannel key doesn't exist. Creating..."
	New-ItemProperty -Path $schannelPath -Name $certMapName -PropertyType DWORD -Value $certMapValue -Force
} else
{
	# If it does exist, set it to 0x4
	Write-Host "[*] Schannel key exists. Setting to 0x4..."
	Set-ItemProperty -Path $schannelPath -Name $certMapName -Value $certMapValue
}

# Confirm the value was set
$newCertMapValue = Get-ItemProperty -Path $schannelPath -Name $certMapName
Write-Host "[+] New CertificateMappingMethods Value: $($newCertMapValue.$certMapName)"
