$ConfigNC = (Get-ADRootDSE).configurationNamingContext
$TemplateOIDPath = "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"

$oa = @{
    DisplayName = "TestIssuancePolicyESC13"
    Name = "TestIssuancePolicyESC13"
    flags = [int]2
    'msPKI-Cert-Template-OID' = "1.2.3.4.5.6.7.8"
}

New-ADObject -Path $TemplateOIDPath -OtherAttributes $oa -Name "TestOID123456789" -Type msPKI-Enterprise-Oid
