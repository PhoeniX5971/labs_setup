#############################################
#  ESC11: DISABLE ENCRYPTED CERT REQ ENFORCEMENT #
#############################################
# Requires:
# - Admin privileges on the CA server
# - PowerShell running elevated
#
# This disables the CA flag enforcing encrypted certificate requests,
# allowing unencrypted cert requests that can be abused in ESC11 attack.

# Run certutil to set the flag
Write-Host "[*] Disabling IF_ENFORCEENCRYPTICERTREQUEST flag..."
certutil.exe -setreg CA\InterfaceFlags -IF_ENFORCEENCRYPTICERTREQUEST

# Restart the ADCS Certificate Services to apply changes
Write-Host "[*] Restarting Certificate Services..."
Restart-Service -Name certsvc -Force

Write-Host "[+] ESC11 flag disabled and Certificate Services restarted."
