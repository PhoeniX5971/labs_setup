$newOIDObj = Get-ADObject -Filter * -SearchBase $OIDContainer -Properties DisplayName,msPKI-Cert-Template-OID | Where-Object { $_.DisplayName -eq $IssuanceName }
if (-not $newOIDObj) {
    Write-Error "Failed to find the new OID object with DisplayName '$IssuanceName'."
    exit
}

$ludus_esc13_group_dn = (Get-ADGroup $esc13group).DistinguishedName
if (-not $ludus_esc13_group_dn) {
    Write-Error "Failed to find the group '$esc13group'."
    exit
}
