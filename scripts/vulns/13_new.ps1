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

        # Proper property access with quotes
        $OID_Forest = (Get-ADObject -Identity "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC" -Properties msPKI-Cert-Template-OID)['msPKI-Cert-Template-OID']

        $msPKICertTemplateOID = "$OID_Forest.$OID_Part_1.$OID_Part_2"
        $Name = "$OID_Part_2.$OID_Part_3"
    } until (IsUniqueOID -cn $Name -TemplateOID $msPKICertTemplateOID -ConfigNC $ConfigNC)
    
    return @{
        TemplateOID  = $msPKICertTemplateOID
        TemplateName = $Name
    }

	Write-Host "esc13templateName = '$esc13templateName'"
	Write-Host "ConfigNC = '$ConfigNC'"
}

try {
    Write-Host "Starting ESC13 vulnerability setup..." -ForegroundColor Cyan

    # Get Configuration NC for AD
    $ADRootDSE = Get-ADRootDSE
    $ConfigNC = $ADRootDSE.configurationNamingContext

    Write-Host "esc13templateName = '$esc13templateName'"
    Write-Host "ConfigNC = '$ConfigNC'"

    # Build the DN of the certificate template
    $ESC13Template = "CN=$esc13templateName,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"
    Write-Host "Looking up certificate template with identity:`n$ESC13Template"

    # Generate unique OID for issuance policy
    $OID = New-TemplateOID -ConfigNC $ConfigNC


	Write-Host "DEBUG: VariableName = '$ESC13Template" -ForegroundColor Yellow
	if ([string]::IsNullOrEmpty($ESC13Template)) { throw "VariableName is NULL before -Identity call" }
    # Check if certificate template exists before proceeding
    $certTemplate = Get-ADObject -Identity $ESC13Template -Properties 'msPKI-Certificate-Policy' -ErrorAction SilentlyContinue
    if (-not $certTemplate) {
        Write-Error "Certificate template '$esc13templateName' not found at path:`n$ESC13Template"
        exit 1
    }

    # Prepare AD object attributes
	#
	Write-Host "OID.TemplateOID value: '$($OID.TemplateOID)'"
	if ([string]::IsNullOrEmpty($OID.TemplateOID)) {
		Write-Error "OID.TemplateOID is null or empty! Cannot create AD object."
		exit 1
	}
	#
	$oa = @{
		DisplayName             = "IssuancePolicyESC13"
		Name                    = "IssuancePolicyESC13"
		flags                   = [int]2
		'msPKI-Cert-Template-OID' = $OID.TemplateOID
	}

		$oa.GetEnumerator() | ForEach-Object {
			Write-Host "$($_.Key) = $($_.Value)"
		}

	Write-Host "DEBUG: VariableName = '$oa" -ForegroundColor Yellow
	if ([string]::IsNullOrEmpty($oa)) { throw "VariableName is NULL before -Identity call" }

    Write-Host "Creating AD object with name: $($OID.TemplateName)"
    Write-Host "Attributes:"
    $oa.GetEnumerator() | ForEach-Object { Write-Host "  $_" }

    $TemplateOIDPath = "CN=OID,CN=Public Key Services,CN=Services,$ConfigNC"

    # Create new AD Object for the OID with error handling
    try {
        $newOIDObj = New-ADObject -Path $TemplateOIDPath -OtherAttributes $oa -Name $OID.TemplateName -Type msPKI-Enterprise-Oid -ErrorAction Stop
        Write-Host "Successfully created new OID AD object." -ForegroundColor Green
    } catch {
        Write-Error "Failed to create AD object for OID '$($OID.TemplateName)': $_"
        exit 1
    }

    # Retrieve msPKI-Cert-Template-OID property from new object
    $newOIDValue = $newOIDObj.'msPKI-Cert-Template-OID'
	Write-Host "1111111111111111111"
    if (-not $newOIDValue) {
        # Try to explicitly fetch if not returned by New-ADObject
		$newOIDObj = New-ADObject -Path $TemplateOIDPath -OtherAttributes $oa -Name $OID.TemplateName -Type msPKI-Enterprise-Oid -ErrorAction Stop

		# Immediately fetch the full AD object
		$newOIDObj = Get-ADObject -Filter { Name -eq $OID.TemplateName } -SearchBase $TemplateOIDPath -Properties 'msPKI-Cert-Template-OID'
    }
	Write-Host "222222222222222222"
    if (-not $newOIDValue) {
        Write-Error "Could not retrieve msPKI-Cert-Template-OID from new OID object."
        exit 1
    }
	Write-Host "33333333333333333"

    # Get certificate template object
    $certTemplate = Get-ADObject -Identity $ESC13Template -Properties 'msPKI-Certificate-Policy'

    # Update certificate template policy with new OID
    $policies = $certTemplate.'msPKI-Certificate-Policy'

    if ($policies) {
        if ($policies -notcontains $newOIDValue) {
            $policies += $newOIDValue
        }
    } else {
        $policies = @($newOIDValue)
    }

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
}
catch {
    Write-Error "An unexpected error occurred: $_"
    exit 1
}
