<#
.SYNOPSIS
    Enables SIDHistory for a trust relationship between two domains.

.DESCRIPTION
    This script uses the `netdom trust` command to enable SIDHistory between 
    two domains. It verifies the trust afterwards and exits with a proper 
    exit code to indicate success or failure.

.PARAMETER SourceDomain
    The source (trusting) domain.

.PARAMETER TargetDomain
    The target (trusted) domain.

.EXAMPLE
    PS> .\Enable-SIDHistory.ps1 -SourceDomain "sevenkingdoms.local" -TargetDomain "essos.local"
    Creates or updates a trust between sevenkingdoms.local and essos.local with SIDHistory enabled.

.NOTES
    Author: Phoenix (example)
    Requires: PowerShell, netdom.exe (included in RSAT or domain controller tools)
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$SourceDomain,

	[Parameter(Mandatory=$true)]
	[string]$TargetDomain
)

Write-Host "Creating trust between $SourceDomain and $TargetDomain with SIDHistory enabled..."

# Create or update the trust with SIDHistory enabled
netdom trust $SourceDomain /d:$TargetDomain /enablesidhistory:yes
if ($LASTEXITCODE -ne 0)
{
	Write-Error "Failed to enable SIDHistory on the trust between $SourceDomain and $TargetDomain"
	exit 1
}

# Verify the trust configuration
Write-Host "Verifying trust..."
netdom trust $SourceDomain /d:$TargetDomain /verify
if ($LASTEXITCODE -ne 0)
{
	Write-Error "Trust verification failed between $SourceDomain and $TargetDomain"
	exit 1
}

Write-Host "Trust created and SIDHistory enabled successfully!"
exit 0
