<#
.SYNOPSIS
Enables a user account without Kerberos pre-authentication, making it vulnerable to AS-REP Roasting.

.DESCRIPTION
This script disables Kerberos pre-authentication for a specified AD user by modifying the 
`userAccountControl` flags. Without pre-authentication, attackers can request an AS-REP 
response containing a crackable hash, even without user interaction.  

If the user does not exist, the script creates a new one with default credentials 
(P@ssw0rd123!) for testing in lab environments.

.REQUIREMENTS
- ActiveDirectory PowerShell module (RSAT tools).
- Permissions to modify the target user account properties.
- Domain-joined machine.

.PARAMETER UserIdentity
The AD user to modify (e.g., "user.noauth").  
If the user does not exist, it will be created.

.EXAMPLE
PS> .\enable_asrep_roasting.ps1 -UserIdentity "user.noauth"
Disables pre-authentication for "user.noauth", making it vulnerable to AS-REP Roasting.

.NOTES
Also known as: AS-REP Roasting  
Flag used: `DONT_REQUIRE_PREAUTH (0x00400000 / 4194304)`
Author: Phoenix (example)  
Use only in labs or controlled test environments.
#>

param(
	[Parameter(Mandatory = $true)]
	[string]$UserIdentity
)

# Ensure the AD module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory))
{
	Write-Error "ActiveDirectory module not found. Please install RSAT tools."
	exit
}
Import-Module ActiveDirectory

# Retrieve the user and check if valid
$user = Get-ADUser -Identity $UserIdentity -Properties userAccountControl -ErrorAction SilentlyContinue
if (-not $user)
{
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
if (-not $currentFlags)
{
	Write-Error "Failed to retrieve userAccountControl flags."
	exit
}

# 4194304 = 0x00400000 (flag for DONT_REQUIRE_PREAUTH)
$DONT_REQUIRE_PREAUTH = 4194304

# Add the flag using bitwise OR
$newFlags = $currentFlags -bor $DONT_REQUIRE_PREAUTH

# Apply the change using -Replace
Set-ADUser -Identity $UserIdentity -Replace @{userAccountControl = $newFlags}
