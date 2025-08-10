<#
.SYNOPSIS
    Setup ESC13 vulnerability for AD CS by creating custom OID issuance policy and linking it to a group.

.PARAMETER esc13group
    The name of the AD group to link the OID to.

.PARAMETER esc13templateName
    The name of the certificate template to modify.

.EXAMPLE
    .\adcs_esc13.ps1 -esc13group "vuln_group" -esc13templateName "WebServer"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$esc13group,

    [Parameter(Mandatory=$true)]
    [string]$esc13templateName
)

# Import required modules
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module ADCSTemplate -ErrorAction SilentlyContinue

function Get-RandomHex {
    param ([int]$Length)
    $Hex = '0123456789ABCDEF'
    $Return = ''
    1..$Length | ForEach-Object {
        $Return += $Hex.Substring((Get-Random -Minimum 0 -Maximum 16),1)
    }
    return $Return
}

function IsUniqueOID {
    param (
        [string]$cn,
        [string]$TemplateOID,
        [string]$ConfigNC
    )
    $Search = Get-ADObject -Filter {cn -eq $cn -and msPKI-Cert-Template-OID -eq $TemplateOID} -SearchBase "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"
    return -not $Search
}

function New-TemplateOID {
    param (
        [string]$ConfigNC
    )
    do {
        $OID_Part_1 = Get-Random -Minimum 10000000 -Maximum 99999999
        $OID_Part_2 = Get-Random -Minimum 10000000 -Maximum 99999999
        $OID_Part_3 = Get-RandomHex -Length 32
        $OID_Forest = (Get-ADObject -Identity "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC" -Properties msPKI-Cert-Template-OID).[`msPKI-Cert-Template-OID`]
        $msPKICertTemplateOID = "$OID_Forest.$OID_Part_1.$OID_Part_2"
        $Name = "$OID_Part_2.$OID_Part_3"
    } until (IsUniqueOID -cn $Name -TemplateOID $msPKICertTemplateOID -ConfigNC $ConfigNC)
    
    return @{
        TemplateOID  = $msPKICertTemplateOID
        TemplateName = $Name
    }
}

try {
    Write-Host "Starting ESC13 vulnerability setup..." -ForegroundColor Cyan

    # Get Configuration NC for AD
    $ADRootDSE = Get-ADRootDSE
    $ConfigNC = $ADRootDSE.configurationNamingContext

    $IssuanceName = "IssuancePolicyESC13"
    $ESC13Template = "CN=$esc13templateName,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"

    # Generate unique OID for issuance policy
    $OID = New-TemplateOID -ConfigNC $ConfigNC

    # OID container path
    $TemplateOIDPath = "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"

    # Create new AD Object for the OID
    $oa = @{
        DisplayName             = $IssuanceName
        Name                    = $IssuanceName
        flags                   = [int]2
        'msPKI-Cert-Template-OID' = $OID.TemplateOID
    }

    Write-Host "Creating new OID object with TemplateOID: $($OID.TemplateOID)" -ForegroundColor Yellow
    $newOIDObj = New-ADObject -Path $TemplateOIDPath -OtherAttributes $oa -Name $OID.TemplateName -Type msPKI-Enterprise-Oid

    # Retrieve the OID object to confirm
    $OIDContainer = "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"
    $OIDs = Get-ADObject -Filter * -SearchBase $OIDContainer -Properties DisplayName,Name,msPKI-Cert-Template-OID,msDS-OIDToGroupLink
    $newOIDObj = $OIDs | Where-Object { $_.DisplayName -eq $IssuanceName }
    $newOIDValue = $newOIDObj.'msPKI-Cert-Template-OID'

    # Get certificate template object
    $certTemplate = Get-ADObject -Identity $ESC13Template -Properties 'msPKI-Certificate-Policy'

    # Update certificate template policy with new OID
    $policies = $certTemplate.'msPKI-Certificate-Policy'

    # Replace or add new policy OID
    if ($policies) {
        # If policies exist, add new one only if not present
        if ($policies -notcontains $newOIDValue) {
            $policies += $newOIDValue
        }
    } else {
        $policies = @($newOIDValue)
    }

    # Write changes
    Write-Host "Updating certificate template '$esc13templateName' with new issuance policy OID..." -ForegroundColor Yellow
    Set-ADObject -Identity $certTemplate.DistinguishedName -Replace @{ 'msPKI-Certificate-Policy' = $policies }

    # Get DN of the group
    $groupDN = (Get-ADGroup -Identity $esc13group).DistinguishedName
    Write-Host "Linking issuance policy to group: $esc13group" -ForegroundColor Yellow

    # Link OID issuance policy to the group
    $object = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($newOIDObj.DistinguishedName)")
    $object.Properties["msDS-OIDToGroupLink"].Value = $groupDN
    $object.CommitChanges()
    $object.RefreshCache()

    Write-Host "ESC13 vulnerability setup complete!" -ForegroundColor Green
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}
