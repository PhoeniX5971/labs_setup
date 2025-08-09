#############################################
#  SETUP ACTIVE DIRECTORY DOMAIN CONTROLLER #
#############################################
# Also known as: AD DS Installation & Promotion
#############################################
# Requires:
# - Running on a Windows Server machine
# - PowerShell running as Administrator
# - User input for DSRM (Directory Services Restore Mode) password
# - Internet connection for feature installation (optional)
#
# This script installs the Active Directory Domain Services role,
# promotes the server to a domain controller, creating a new forest,
# DNS zone, and domain using provided domain names and secure password.
#############################################

param(
    [Parameter(Mandatory=$true)]
    [string]$DomainName,

    [Parameter(Mandatory=$true)]
    [string]$NetBIOSName
)

# Prompt interactively for DSRM password securely inside the script
$SafeModeAdminPassword = Read-Host "Enter DSRM password (for Directory Services Restore Mode)" -AsSecureString

function Install-ADDomainController {
    Write-Host "Installing Active Directory Domain Services role..."
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -Verbose

    Write-Host "Importing ADDSDeployment module..."
    Import-Module ADDSDeployment -ErrorAction Stop

    Write-Host "Checking for ActiveDirectory PowerShell module..."

    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-Host "ActiveDirectory module not found. Attempting to install RSAT feature..."

        Install-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature -IncludeManagementTools -Verbose -ErrorAction Stop

        Write-Host "ActiveDirectory module installed."
    }
    else {
        Write-Host "ActiveDirectory module found."
    }

    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "ActiveDirectory module imported successfully."

    Write-Host "Promoting this server to Domain Controller for domain: $DomainName"
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $NetBIOSName `
        -SafeModeAdministratorPassword $SafeModeAdminPassword `
        -InstallDns `
        -Force:$true `
        -NoRebootOnCompletion:$false

    Write-Host "Domain Controller installation complete. The server will reboot to finalize setup."
}

# Execute the installation
Install-ADDomainController

# Usage Example
# .\setup_ad_for_win_server.ps1 -DomainName "mydomain.local" -NetBIOSName "MYDOMAIN"
