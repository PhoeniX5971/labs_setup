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

$kdcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Kdc"
$kdcName = "StrongCertificateBindingEnforcement"
$kdcValue = 0

$currentKdcValue = Get-ItemProperty -Path $kdcPath -Name $kdcName -ErrorAction SilentlyContinue

if ($null -eq $currentKdcValue)
{
	Write-Host "[*] KDC key doesn't exist. Creating..." -ForegroundColor Cyan
	New-ItemProperty -Path $kdcPath -Name $kdcName -PropertyType DWORD -Value $kdcValue -Force
} else
{
	Write-Host "[*] KDC key exists. Setting to 0..." -ForegroundColor Cyan
	Set-ItemProperty -Path $kdcPath -Name $kdcName -Value $kdcValue
}

$newKdcValue = Get-ItemProperty -Path $kdcPath -Name $kdcName
Write-Host "[+] New KDC Value: $($newKdcValue.$kdcName)" -ForegroundColor Green

########################################################
#  SET 2: ENABLE UPN-ONLY MAPPING (SCHANNEL REGISTRY)  #
########################################################

$schannelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\Schannel"
$certMapName = "CertificateMappingMethods"
$certMapValue = 0x4

$currentCertMap = Get-ItemProperty -Path $schannelPath -Name $certMapName -ErrorAction SilentlyContinue

if ($null -eq $currentCertMap)
{
	Write-Host "[*] Schannel key doesn't exist. Creating..." -ForegroundColor Cyan
	New-ItemProperty -Path $schannelPath -Name $certMapName -PropertyType DWORD -Value $certMapValue -Force
} else
{
	Write-Host "[*] Schannel key exists. Setting to 0x4..." -ForegroundColor Cyan
	Set-ItemProperty -Path $schannelPath -Name $certMapName -Value $certMapValue
}

$newCertMapValue = Get-ItemProperty -Path $schannelPath -Name $certMapName
Write-Host "[+] New CertificateMappingMethods Value: $($newCertMapValue.$certMapName)" -ForegroundColor Green

########################################################
#  CHECKER: VERIFY BOTH CHANGES AND EXIT CODE         #
########################################################

$kdcCheck = (Get-ItemProperty -Path $kdcPath -Name $kdcName -ErrorAction SilentlyContinue).$kdcName
$certMapCheck = (Get-ItemProperty -Path $schannelPath -Name $certMapName -ErrorAction SilentlyContinue).$certMapName

if ($kdcCheck -eq $kdcValue -and $certMapCheck -eq $certMapValue)
{
	Write-Host "[SUCCESS] All registry changes applied correctly!" -ForegroundColor Green
	exit 0
} else
{
	Write-Host "[FAIL] One or more registry changes failed!" -ForegroundColor Red
	exit 1
}
