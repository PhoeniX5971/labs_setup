#############################################
#  ESC13: Issuance Policy OID to Group Link #
#############################################
# Requires:
# - Run on Domain Controller
# - ADCS installed with existing cert template
# - PowerShell running as domain admin
#
# This simulates ESC13 by creating a new issuance policy OID and linking it to a group.
#
# Parameters:
# -esc13group        : AD group to link OID to (e.g., vuln_group)
# -esc13templateName : Certificate template name to apply the new OID to (e.g., WebServer)
#

param(
    [Parameter(Mandatory = $true)]
    [string]$esc13group,

    [Parameter(Mandatory = $true)]
    [string]$esc13templateName
)

function Debug-Write {
    param([string]$message)
    Write-Host "[DEBUG] $message"
}

# Import modules with error handling
try {
    Import-Module ADCSTemplate -ErrorAction SilentlyContinue
    Debug-Write "ADCSTemplate module imported successfully."
} catch {
    Write-Error "Failed to import ADCSTemplate module: $_"
    exit 1
}

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Debug-Write "ActiveDirectory module imported successfully."
} catch {
    Write-Error "Failed to import ActiveDirectory module: $_"
    exit 1
}

# Function to generate a random hex string
function Get-RandomHex {
    param ([int]$Length)
    $Hex = '0123456789ABCDEF'
    $Return = ''
    1..$Length | ForEach-Object {
        $Return += $Hex.Substring((Get-Random -Minimum 0 -Maximum 16),1)
    }
    return $Return
}

# Check if OID is unique in AD
function IsUniqueOID {
    param ($cn, $TemplateOID, $ConfigNC)
    $Search = Get-ADObject -Filter {cn -eq $cn -and msPKI-Cert-Template-OID -eq $TemplateOID} -SearchBase "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"
    return -not $Search
}

# Generate a new unique OID
function New-TemplateOID {
    param($ConfigNC)
    do {
        $OID_Part_1 = Get-Random -Minimum 10000000 -Maximum 99999999
        $OID_Part_2 = Get-Random -Minimum 10000000 -Maximum 99999999
        $OID_Part_3 = Get-RandomHex -Length 32
        $OID_Forest = (Get-ADObject -Identity "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC" -Properties msPKI-Cert-Template-OID).'msPKI-Cert-Template-OID'
        $msPKICertTemplateOID = "$OID_Forest.$OID_Part_1.$OID_Part_2"
        $Name = "$OID_Part_2.$OID_Part_3"
    } until (IsUniqueOID -cn $Name -TemplateOID $msPKICertTemplateOID -ConfigNC $ConfigNC)
    return @{
        TemplateOID  = $msPKICertTemplateOID
        TemplateName = $Name
    }
}

# Main
try {
    $ADRootDSE = Get-ADRootDSE
    $ConfigNC = $ADRootDSE.configurationNamingContext
    Debug-Write "ConfigNC: $ConfigNC"

    # Build LDAP paths
    $ESC13Template = "CN=$esc13templateName,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"
    Debug-Write "Using template LDAP path: $ESC13Template"

    # Create a new unique OID
    $OID = New-TemplateOID -ConfigNC $ConfigNC
    Debug-Write "Generated OID: $($OID.TemplateOID) with Name: $($OID.TemplateName)"

    $TemplateOIDPath = "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"
    Debug-Write "Template OID Path: $TemplateOIDPath"

    # Create the new OID AD object
    $oa = @{
        'DisplayName' = "IssuancePolicyESC13"
        'Name' = "IssuancePolicyESC13"
        'flags' = [int]2
        'msPKI-Cert-Template-OID' = $OID.TemplateOID
    }
    New-ADObject -Path $TemplateOIDPath -OtherAttributes $oa -Name $OID.TemplateName -Type 'msPKI-Enterprise-Oid'
    Debug-Write "Created new OID object: $($OID.TemplateName)"

    # Step 4: Apply OID to the certificate template
    $OIDContainer = "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"
    Debug-Write "OID Container: $OIDContainer"

    $newOIDObj = Get-ADObject -SearchBase $OIDContainer -Filter "Name -eq '$($OID.TemplateName)'" -Properties DisplayName, msPKI-Cert-Template-OID
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

    # Step 5: Link the OID to the group
    $ludus_esc13_group_dn = (Get-ADGroup -Identity $esc13group).DistinguishedName
    if (-not $ludus_esc13_group_dn) {
        Write-Error "Group '$esc13group' not found."
        exit 1
    }
    Debug-Write "Group DN: $ludus_esc13_group_dn"

    $esc13OID_dn = $newOIDObj.DistinguishedName
    $object = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$esc13OID_dn")

    # Get current values of msDS-OIDToGroupLink
    $currentLinks = @()
    if ($object.Properties["msDS-OIDToGroupLink"].Count -gt 0) {
        $currentLinks = $object.Properties["msDS-OIDToGroupLink"] | ForEach-Object { $_ }
    }

    # Add group DN if not present
    if ($currentLinks -contains $ludus_esc13_group_dn) {
        Write-Host "Group is already linked to OID. Skipping addition."
    }
    else {
        Write-Host "Adding group link to OID."
        $object.Properties["msDS-OIDToGroupLink"].Add($ludus_esc13_group_dn) | Out-Null
        $object.CommitChanges()
        Write-Host "[+] ESC13 OID linked to group '$esc13group' successfully."
    }
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
