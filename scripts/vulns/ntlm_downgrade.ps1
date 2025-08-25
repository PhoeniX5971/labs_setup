<#
.SYNOPSIS
Sets the LMCompatibilityLevel to a weaker value, allowing fallback to NTLMv1.

.DESCRIPTION
This script modifies the registry key "LmCompatibilityLevel" to weaken NTLM authentication settings.  
Setting it to 2 permits NTLMv1 responses while still supporting NTLMv2.  
This can make systems vulnerable to NTLM downgrade attacks.  

Value mapping:
0 = Send LM & NTLM responses  
1 = Send LM & NTLM – use NTLMv2 session security if negotiated  
2 = Send NTLM response only (current setting in this script)  
3 = Send NTLMv2 response only  
4 = Send NTLMv2 response only. Refuse LM  
5 = Send NTLMv2 response only. Refuse LM & NTLM  

.REFERENCES
https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-security-lan-manager-authentication-level

.EXAMPLE
PS> .\set_lm_compatibility_weak.ps1
Configures the system to send NTLM responses only, allowing fallback to NTLMv1.

.NOTES
Author: Phoenix (example)  
Intended for lab/testing purposes. Do not use in production environments.
#>

$path = "HKLM:\System\CurrentControlSet\Control\Lsa"
$name = "LmCompatibilityLevel"
$value = 2

Write-Host "[*] Setting LMCompatibilityLevel to $value..." -ForegroundColor Cyan

# Apply the registry change
Set-ItemProperty -Path $path -Name $name -Value $value -Type DWord -Verbose

# Verify the change
$currentValue = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $name

if ($currentValue -eq $value)
{
	Write-Host "[SUCCESS] LMCompatibilityLevel successfully set to $value." -ForegroundColor Green
	exit 0
} else
{
	Write-Host "[FAIL] Failed to set LMCompatibilityLevel. Current value: $currentValue" -ForegroundColor Red
	exit 1
}
