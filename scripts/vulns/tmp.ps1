$esc13OID_dn = $newOIDObj.DistinguishedName
$ludus_esc13_group_dn = (Get-ADGroup $esc13group).DistinguishedName

$object = [ADSI]"LDAP://$esc13OID_dn"

# ADSI constant 3 = ADS_PROPERTY_APPEND
$ADS_PROPERTY_APPEND = 3

try {
    $object.PutEx($ADS_PROPERTY_APPEND, "msDS-OIDToGroupLink", $ludus_esc13_group_dn)
    $object.SetInfo()
    Write-Host "[+] Successfully linked group to OID."
}
catch {
    Write-Error "Failed to link group to OID: $_"
}
