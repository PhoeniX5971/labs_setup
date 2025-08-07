param(
    [switch]$AddSPN,
    [switch]$DisableFirewall,
    [switch]$EnableASREP,
    [switch]$UnconstrainedDelegation,
    [switch]$SetupAD,
    [switch]$ACLAbuse,

    # Shared/Optional Params
    [string]$UserIdentity,
    [string]$ServicePrincipalName,
    [string]$TargetUser,
    [string]$LowPrivUser,
    [string]$DomainName,
    [string]$NetBIOSName
)


if ($SetupAD) {
    .\setup_ad_for_win_server.ps1 -DomainName $DomainName -NetBIOSName $NetBIOSName
}

if ($AddSPN) {
    .\add_spn_for_kerberoasting.ps1 -UserIdentity $UserIdentity -ServicePrincipalName $ServicePrincipalName
}

if ($DisableFirewall) {
    .\disable_firewall.ps1
}

if ($EnableASREP) {
    .\enable_asrep_roasting.ps1 -UserIdentity $UserIdentity
}

if ($UnconstrainedDelegation) {
    .\enable_unconstrained_delegation.ps1 -UserIdentity $UserIdentity
}

if ($ACLAbuse) {
    .\weak_perms_on_user.ps1 -TargetUser $TargetUser -LowPrivUser $LowPrivUser
}

# Usage:
# .\master.ps1 -AddSPN -UserIdentity "svc-sql" -ServicePrincipalName "MSSQLSvc/sql.srv.local:1433"
# .\master.ps1 -DisableFirewall
# .\master.ps1 -EnableASREP -UserIdentity "user.noauth"
# .\master.ps1 -UnconstrainedDelegation -UserIdentity "target.user"
# .\master.ps1 -SetupAD -DomainName "corp.local" -NetBIOSName "CORP"
# .\master.ps1 -ACLAbuse -TargetUser "domainadmin" -LowPrivUser "low.priv"
