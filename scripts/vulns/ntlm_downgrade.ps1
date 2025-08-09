######################################################
#  SET LM COMPATIBILITY LEVEL TO WEAK (Value: 2)     #
######################################################
# Allows NTLMv2 authentication but also permits
# fallback to NTLMv1. Vulnerable to NTLMv1 downgrade.
# Reference: https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-security-lan-manager-authentication-level
# Value mapping:
# 0 = Send LM & NTLM responses
# 1 = Send LM & NTLM - use NTLMv2 session security if negotiated
# 2 = Send NTLM response only
# 3 = Send NTLMv2 response only
# 4 = Send NTLMv2 response only. Refuse LM
# 5 = Send NTLMv2 response only. Refuse LM & NTLM

Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -Value 2 -Type DWord -Verbose
