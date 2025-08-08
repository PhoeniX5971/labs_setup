#############################################################
#                   ENABLE SMBv1 FEATURE                    #
#############################################################
# Enables the SMBv1 protocol on the target system.          #
# This is an outdated and insecure protocol and should      #
# only be enabled in testing or lab environments.           #
#                                                           #
# A reboot will be triggered only if it's required.         #
#############################################################

# Check if SMB1Protocol is installed
$feature = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol

if ($feature.State -ne 'Enabled') {
    Write-Host "[*] Enabling SMB1Protocol..." -ForegroundColor Cyan
    Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -All -NoRestart

    if ($feature.RestartNeeded -or (Get-ComputerInfo | Select-Object -ExpandProperty WindowsProductName -like '*Server*')) {
        Write-Host "[!] Reboot is required. Restarting now..." -ForegroundColor Yellow
        Restart-Computer -Force
    } else {
        Write-Host "[*] SMB1Protocol enabled. No reboot required." -ForegroundColor Green
    }
} else {
    Write-Host "[+] SMB1Protocol is already enabled." -ForegroundColor Green
}
