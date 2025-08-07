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

# Retrieve the user and check if valid
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

$currentFlags = $user.userAccountControl
if (-not $currentFlags) {
    Write-Error "Failed to retrieve userAccountControl flags."
    exit
}

# 4194304 = 0x00400000 (flag for DONT_REQUIRE_PREAUTH)
$DONT_REQUIRE_PREAUTH = 4194304

# Add the flag using bitwise OR
$newFlags = $currentFlags -bor $DONT_REQUIRE_PREAUTH

# Apply the change using -Replace
Set-ADUser -Identity $UserIdentity -Replace @{userAccountControl = $newFlags}

# Usage:
# .\enable_asrep_roasting.ps1 -UserIdentity "user.noauth"
