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

Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -Value 2 -Type DWord -Verbose
