#############################################
#  ENABLE USER WITHOUT PRE-AUTHENTICATION   #
#############################################
# Also known as: AS-REP Roasting            #
#############################################
# Requires:
# - ActiveDirectory PowerShell module
# - Permissions to modify user account properties
# - Domain-joined machine
#
# Disables Kerberos pre-authentication for a user.
# This makes the user vulnerable to AS-REP Roasting, allowing password hash extraction
# even without the user interacting.

param(
    [Parameter(Mandatory = $true)]
    [string]$UserIdentity
)

# Ensure the AD module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module not found. Please install RSAT tools."
    exit
}
Import-Module ActiveDirectory

# Disable pre-authentication for the specified user
Set-ADUser -Identity $UserIdentity -DoesNotRequirePreAuth $true

# Usage:
# .\enable_asrep_roasting.ps1 -UserIdentity "user.noauth"
