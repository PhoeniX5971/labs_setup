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
    [string]$esc13templateName,

    [switch]$dbg
)

function Debug-Write {
    param([string]$msg)
    if ($dbg) { Write-Host "[DEBUG] $msg" }
}

try {
    Import-Module ADCSTemplate -ErrorAction SilentlyContinue
    Import-Module ActiveDirectory -ErrorAction Stop
    Debug-Write "Modules imported successfully."
} catch {
    Write-Error "Failed to import required modules: $_"
    exit 1
}

Function Get-RandomHex {
    param ([int]$Length)
    $Hex = '0123456789ABCDEF'
    $Return = ''
    1..$Length | ForEach-Object {
        $Return += $Hex.Substring((Get-Random -Minimum 0 -Maximum 16),1)
    }
    return $Return
}

Function IsUniqueOID {
    param ($cn, $TemplateOID, $ConfigNC)
    $Search = Get-ADObject -Filter {cn -eq $cn -and msPKI-Cert-Template-OID -eq $TemplateOID} -SearchBase "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"
    if ($Search) { return $false } else { return $true }
}

Function New-TemplateOID {
    param($ConfigNC)
    do {
        $OID_Part_1 = Get-Random -Minimum 10000000 -Maximum 99999999
        $OID_Part_2 = Get-Random -Minimum 10000000 -Maximum 99999999
        $OID_Part_3 = Get-RandomHex -Length 32
        $OID_Forest = Get-ADObject -Identity "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC" -Properties msPKI-Cert-Template-OID | Select-Object -ExpandProperty msPKI-Cert-Template-OID
        $msPKICertTemplateOID = "$OID_Forest.$OID_Part_1.$OID_Part_2"
        $Name = "$OID_Part_2.$OID_Part_3"
        Debug-Write "Generated OID: $msPKICertTemplateOID with Name: $Name"
    } until (IsUniqueOID -cn $Name -TemplateOID $msPKICertTemplateOID -ConfigNC $ConfigNC)
    return @{
        TemplateOID  = $msPKICertTemplateOID
        TemplateName = $Name
    }
}

try {
    # Step 1: Get configuration context
    $ADRootDSE = Get-ADRootDSE
    $ConfigNC = $ADRootDSE.configurationNamingContext
    Debug-Write "ConfigNC: $ConfigNC"

    if (-not $ConfigNC) {
        Write-Error "Failed to retrieve configurationNamingContext. Are you running this on a domain-joined machine?"
        exit 1
    }

    # Step 2: Build OID structure
    $IssuanceName = "IssuancePolicyESC13"
    $ESC13Template = "CN=$esc13templateName,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"
    Debug-Write "Using template LDAP path: $ESC13Template"

    $OID = New-TemplateOID -ConfigNC $ConfigNC

    $TemplateOIDPath = "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"
    Debug-Write "Template OID Path: $TemplateOIDPath"

    # Step 3: Create new OID object
    $oa = @{
        'DisplayName' = $IssuanceName
        'Name' = $IssuanceName
        'flags' = [System.Int32]'2'
        'msPKI-Cert-Template-OID' = $OID.TemplateOID
    }

    Debug-Write "Creating new OID object with properties: $($oa | Out-String)"
    New-ADObject -Path $TemplateOIDPath -OtherAttributes $oa -Name $OID.TemplateName -Type 'msPKI-Enterprise-Oid'
    Write-Host "[+] Created new OID object: $($OID.TemplateName)"

} catch {
    Write-Error "Error creating new OID object: $_"
    exit 1
}

try {
    # Step 4: Apply OID to the certificate template
    $OIDContainer = "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"
    Debug-Write "OID Container: $OIDContainer"

    # Try to get new OID object by Name (use TemplateName because DisplayName may differ)
    $newOIDObj = Get-ADObject -SearchBase $OIDContainer -Filter {Name -eq $OID.TemplateName} -Properties DisplayName, msPKI-Cert-Template-OID
    if (-not $newOIDObj) {
        Write-Error "Failed to find new OID object by Name '$($OID.TemplateName)'."
        exit 1
    }
    Debug-Write "Found OID object with DN: $($newOIDObj.DistinguishedName)"

    $newOIDValue = $newOIDObj.'msPKI-Cert-Template-OID'
    Debug-Write "OID Value to assign: $newOIDValue"

    $adObject = Get-ADObject -Identity $ESC13Template -Properties msPKI-Certificate-Policy
    if (-not $adObject) {
        Write-Error "Certificate template '$esc13templateName' not found."
        exit 1
    }
    Debug-Write "Certificate template DN: $($adObject.DistinguishedName)"
    
    $policies = @($newOIDValue)
    Set-ADObject -Identity $adObject.DistinguishedName -Replace @{ 'msPKI-Certificate-Policy' = $policies }
    Write-Host "[+] Applied OID to certificate template '$esc13templateName'"

} catch {
    Write-Error "Error applying OID to certificate template: $_"
    exit 1
}

try {
    # Step 5: Link the OID to the group
    $ludus_esc13_group_dn = (Get-ADGroup -Identity $esc13group).DistinguishedName
    if (-not $ludus_esc13_group_dn) {
        Write-Error "Group '$esc13group' not found."
        exit 1
    }
    Debug-Write "Group DN: $ludus_esc13_group_dn"

    $esc13OID_dn = $newOIDObj.DistinguishedName
    $object = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$esc13OID_dn")

    # Clear existing and add new group link
    $object.Properties["msDS-OIDToGroupLink"].Clear()
    $object.Properties["msDS-OIDToGroupLink"].Add($ludus_esc13_group_dn)
    $object.CommitChanges()
    Write-Host "[+] ESC13 OID linked to group '$esc13group' successfully."
} catch {
    Write-Error "Failed to link OID to group: $_"
    exit 1
}
