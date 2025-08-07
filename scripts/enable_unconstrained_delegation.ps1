#############################################
#  ENABLE UNCONSTRAINED DELEGATION          #
#############################################
# Also known as: Delegation Abuse           #
#############################################
# Requires:
# - Permissions to modify the target user's account
# - Domain-joined machine
#
# This allows the user to impersonate other users (including higher-privileged ones)
# after authenticating to a service hosted by this account.
#
# Parameters:
# -UserIdentity : The AD user to modify (e.g., target.user)
#

param(
    [Parameter(Mandatory=$true)]
    [string]$UserIdentity
)


# Ensure the AD module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module not found. Please install RSAT tools."
    exit
}
Import-Module ActiveDirectory

$user = Get-ADUser -Identity $UserIdentity -Properties userAccountControl -ErrorAction SilentlyContinue
if (-not $user) {
    Write-Host "User '$UserIdentity' not found. Creating new user..."
    # Adjust these parameters as needed for your environment
    New-ADUser -Name $UserIdentity `
               -SamAccountName $UserIdentity `
               -AccountPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
               -Enabled $true `
			   -PasswordNeverExpires $true
    # Optionally, re-fetch the user object
    $user = Get-ADUser -Identity $UserIdentity -Properties userAccountControl
}

Set-ADAccountControl -Identity $UserIdentity -TrustedForDelegation $true

# Usage:
# .\enable_unconstrained_delegation.ps1 -UserIdentity "target.user"
