#############################################
#  ESC13: Issuance Policy OID to Group Link #
#############################################
# Requires:
# - Run on Domain Controller
# - ADCS installed with existing cert template
# - PowerShell running as domain admin
#
# This simulates ESC13 by creating a new issuance policy OID and linking it to a group.

param(
    [Parameter(Mandatory = $true)]
    [string]$esc13group,

    [Parameter(Mandatory = $true)]
    [string]$esc13templateName
)

Import-Module ADCSTemplate -ErrorAction SilentlyContinue
Import-Module ActiveDirectory -ErrorAction Stop

Function Get-RandomHex {
    param ([int]$Length)
    $Hex = '0123456789ABCDEF'
    $Return = ''
    1..$Length | ForEach-Object {
        $Return += $Hex.Substring((Get-Random -Minimum 0 -Maximum 16),1)
    }
    Return $Return
}

Function IsUniqueOID {
    param ($cn, $TemplateOID, $ConfigNC)
    $Search = Get-ADObject -Filter {cn -eq $cn -and msPKI-Cert-Template-OID -eq $TemplateOID} -SearchBase "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"
    If ($Search) {$False} Else {$True}
}

Function New-TemplateOID {
    Param($ConfigNC)
    do {
        $OID_Part_1 = Get-Random -Minimum 10000000 -Maximum 99999999
        $OID_Part_2 = Get-Random -Minimum 10000000 -Maximum 99999999
        $OID_Part_3 = Get-RandomHex -Length 32
        $OID_Forest = Get-ADObject -Identity "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC" -Properties msPKI-Cert-Template-OID |
            Select-Object -ExpandProperty msPKI-Cert-Template-OID
        $msPKICertTemplateOID = "$OID_Forest.$OID_Part_1.$OID_Part_2"
        $Name = "$OID_Part_2.$OID_Part_3"
    } until (IsUniqueOID -cn $Name -TemplateOID $msPKICertTemplateOID -ConfigNC $ConfigNC)
    Return @{
        TemplateOID  = $msPKICertTemplateOID
        TemplateName = $Name
    }
}

# Step 1: Get configuration context
$ADRootDSE = Get-ADRootDSE
$ConfigNC = $ADRootDSE.configurationNamingContext

# Step 2: Build OID structure
$IssuanceName = "IssuancePolicyESC13"
$ESC13Template = "CN=$esc13templateName,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"
$OID = New-TemplateOID -ConfigNC $ConfigNC
$TemplateOIDPath = "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"

# Step 3: Create new OID object
$oa = @{
    'DisplayName' = $IssuanceName
    'Name' = $IssuanceName
    'flags' = [System.Int32]'2'
    'msPKI-Cert-Template-OID' = $OID.TemplateOID
}
New-ADObject -Path $TemplateOIDPath -OtherAttributes $oa -Name $OID.TemplateName -Type 'msPKI-Enterprise-Oid'

# Step 4: Apply OID to the certificate template
$OIDContainer = "CN=OID,CN=Public Key Services,CN=Services," + $ConfigNC
$newOIDObj = Get-ADObject -SearchBase $OIDContainer -Filter {Name -eq $OID.TemplateName} -Properties DisplayName, msPKI-Cert-Template-OID
$newOIDValue = $newOIDObj.'msPKI-Cert-Template-OID'

$adObject = Get-ADObject $ESC13Template -Properties msPKI-Certificate-Policy
$policies = @($newOIDValue)
Set-ADObject -Identity $adObject.DistinguishedName -Replace @{ 'msPKI-Certificate-Policy' = $policies }

# Step 5: Link the OID to the group
$ludus_esc13_group_dn = (Get-ADGroup $esc13group).DistinguishedName
$esc13OID_dn = $newOIDObj.DistinguishedName
$object = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$esc13OID_dn")

try {
    # Clear existing links, then add new one
    $object.Properties["msDS-OIDToGroupLink"].Clear()
    $object.Properties["msDS-OIDToGroupLink"].Add($ludus_esc13_group_dn)
    $object.CommitChanges()
    Write-Host "[+] ESC13 OID linked to group $esc13group successfully."
}
catch {
    Write-Error "Failed to link OID to group: $_"
}
