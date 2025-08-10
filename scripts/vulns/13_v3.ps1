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

        $OID_Forest = (Get-ADObject -Identity "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC" -Properties msPKI-Cert-Template-OID).'msPKI-Cert-Template-OID'

        $msPKICertTemplateOID = "$OID_Forest.$OID_Part_1.$OID_Part_2"
        $Name = "$OID_Part_2.$OID_Part_3"
    } until (IsUniqueOID -cn $Name -TemplateOID $msPKICertTemplateOID -ConfigNC $ConfigNC)
    
    Write-Host "[DEBUG] Generated OID: $msPKICertTemplateOID with name: $Name"
    
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

    Write-Host "Working with template: '$esc13templateName'"
    Write-Host "Configuration NC: '$ConfigNC'"

    # Build the DN of the certificate template
    $ESC13Template = "CN=$esc13templateName,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"
    Write-Host "Looking up certificate template at: $ESC13Template"

    # Generate unique OID for issuance policy
    $OID = New-TemplateOID -ConfigNC $ConfigNC
    Write-Host "Generated OID details:"
    Write-Host "  TemplateOID: $($OID.TemplateOID)"
    Write-Host "  TemplateName: $($OID.TemplateName)"

    # Check if certificate template exists before proceeding
    $certTemplate = Get-ADObject -Identity $ESC13Template -Properties 'msPKI-Certificate-Policy' -ErrorAction SilentlyContinue
    if (-not $certTemplate) {
        throw "Certificate template '$esc13templateName' not found at path: $ESC13Template"
    }

    # Prepare AD object attributes
    $oa = @{
        DisplayName             = "IssuancePolicyESC13"
        Name                    = "IssuancePolicyESC13"
        flags                   = [int]2
        'msPKI-Cert-Template-OID' = $OID.TemplateOID
    }

    Write-Host "Creating new AD object with attributes:"
    $oa.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key): $($_.Value)" }

    $TemplateOIDPath = "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"

    # Check for existing object first
    $existingOIDObj = Get-ADObject -Filter { Name -eq $OID.TemplateName } -SearchBase $TemplateOIDPath -ErrorAction SilentlyContinue
    if ($existingOIDObj) {
        Write-Host "Removing existing OID object: $($existingOIDObj.DistinguishedName)"
        Remove-ADObject -Identity $existingOIDObj.DistinguishedName -Confirm:$false
    }

    # Create new AD Object for the OID
    $newOIDObj = New-ADObject -Path $TemplateOIDPath -OtherAttributes $oa -Name $OID.TemplateName -Type msPKI-Enterprise-Oid -PassThru
    if (-not $newOIDObj) {
        throw "Failed to create AD object for OID '$($OID.TemplateName)'"
    }

    # Get the full object with all properties
    $newOIDObj = Get-ADObject -Identity $newOIDObj.DistinguishedName -Properties 'msPKI-Cert-Template-OID'
    $newOIDValue = $newOIDObj.'msPKI-Cert-Template-OID'
    
    if (-not $newOIDValue) {
        throw "Could not retrieve msPKI-Cert-Template-OID from new OID object"
    }

    # Update certificate template policy with new OID
    $certTemplate = Get-ADObject -Identity $ESC13Template -Properties 'msPKI-Certificate-Policy'
    $policies = @($certTemplate.'msPKI-Certificate-Policy' | Where-Object { $_ -ne $null })

    if ($policies -notcontains $newOIDValue) {
        $policies += $newOIDValue
    }

    Write-Host "Updating certificate template with new issuance policy OID..."
    Set-ADObject -Identity $certTemplate.DistinguishedName -Replace @{ 'msPKI-Certificate-Policy' = $policies }

    # Get DN of the group
    $groupDN = (Get-ADGroup -Identity $esc13group).DistinguishedName
    Write-Host "Linking issuance policy to group: $esc13group"

    # Link OID issuance policy to the group
    $object = [ADSI]"LDAP://$($newOIDObj.DistinguishedName)"
    $object.Properties["msDS-OIDToGroupLink"].Value = $groupDN
    $object.CommitChanges()

    Write-Host "ESC13 vulnerability setup complete!" -ForegroundColor Green
}
catch {
    Write-Error "ERROR: $_"
    Write-Host "Error details:" -ForegroundColor Red
    Write-Host "  Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "  Error Message: $($_.Exception.Message)"
    Write-Host "  Stack Trace: $($_.ScriptStackTrace)"
    exit 1
}
