<#
.SYNOPSIS
Automated checker for ADCS weak mapping settings.

.DESCRIPTION
Checks if:
1. KDC StrongCertificateBindingEnforcement is disabled (0)
2. Schannel CertificateMappingMethods is set to UPN-only (0x4)

Exits with:
- 0 if both checks pass
- 1 if either check fails

Outputs simple success/failure messages.
#>

# Define expected values
$expectedKdcValue = 0
$expectedCertMapValue = 0x4

# Define registry paths
$kdcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Kdc"
$kdcName = "StrongCertificateBindingEnforcement"

$schannelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\Schannel"
$certMapName = "CertificateMappingMethods"

# --- Check KDC ---
$kdcCheck = Get-ItemProperty -Path $kdcPath -Name $kdcName -ErrorAction SilentlyContinue
if ($null -ne $kdcCheck -and $kdcCheck.$kdcName -eq $expectedKdcValue)
{
	Write-Host "[+] KDC StrongCertificateBindingEnforcement is correctly set to $expectedKdcValue"
	$kdcStatus = $true
} else
{
	Write-Host "[-] KDC StrongCertificateBindingEnforcement is NOT correctly set"
	$kdcStatus = $false
}

# --- Check Schannel ---
$certMapCheck = Get-ItemProperty -Path $schannelPath -Name $certMapName -ErrorAction SilentlyContinue
if ($null -ne $certMapCheck -and $certMapCheck.$certMapName -eq $expectedCertMapValue)
{
	Write-Host "[+] Schannel CertificateMappingMethods is correctly set to 0x$("{0:X}" -f $expectedCertMapValue)"
	$certMapStatus = $true
} else
{
	Write-Host "[-] Schannel CertificateMappingMethods is NOT correctly set"
	$certMapStatus = $false
}

# --- Exit code ---
if ($kdcStatus -and $certMapStatus)
{
	exit 0
} else
{
	exit 1
}
