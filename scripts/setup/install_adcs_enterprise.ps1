#############################################
#  INSTALL ENTERPRISE ROOT CA & MODULES     #
#############################################
# Also known as: AD CS Base Setup            #
#############################################
# Requires:
# - Windows Server (domain-joined)
# - Domain Admin or Enterprise Admin rights
# - PowerShell run as Administrator
#
# This installs Active Directory Certificate Services (AD CS)
# as an Enterprise Root Certification Authority and sets up the
# ADCSTemplate PowerShell module for managing certificate templates.
#
# Notes:
# - Enterprise CA is required for certificate templates
# - These commands should be run only in a test/lab environment
#

#############################################
#  Step 1: Install Enterprise Root CA       #
#############################################

# Check if AD CS role is already installed
if (Get-WindowsFeature Adcs-Cert-Authority | Where-Object {$_.InstallState -eq "Installed"}) {
    Write-Host "[*] AD CS is already installed. Skipping installation." -ForegroundColor Green
} else {
    Write-Host "[*] Installing AD CS role..." -ForegroundColor Yellow
    Install-WindowsFeature Adcs-Cert-Authority -IncludeManagementTools
}

# Check if CA is already configured
$caService = Get-Service -Name CertSvc -ErrorAction SilentlyContinue
if ($caService -and $caService.Status -ne $null) {
    Write-Host "[*] Enterprise CA is already configured. Skipping configuration." -ForegroundColor Green
} else {
    Write-Host "[*] Configuring Enterprise Root CA..." -ForegroundColor Yellow
    Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -Force
}

#############################################
#  Step 2: Install ADCSTemplate Module      #
#############################################

# Check if ADCSTemplate module is installed
if (Get-Module -ListAvailable -Name ADCSTemplate) {
    Write-Host "[*] ADCSTemplate module is already installed." -ForegroundColor Green
} else {
    Write-Host "[*] Installing ADCSTemplate module..." -ForegroundColor Yellow
    Install-Module -Name ADCSTemplate -Scope AllUsers -Force
}

# Import the ADCSTemplate module
Import-Module ADCSTemplate
Write-Host "[+] ADCSTemplate module imported successfully." -ForegroundColor Green
