<#
.SYNOPSIS
    Temporarily sets ExecutionPolicy to Bypass, runs the master script, and restores original settings.

.DESCRIPTION
    Automatically handles execution policy changes. Captures original policy, applies Bypass for both
    CurrentUser and LocalMachine, runs `master.ps1` with arguments, and resets the original policy.
#>

param(
    [Parameter(Mandatory=$false)]
    [string[]]$MasterArgs
)

$Scopes = @("LocalMachine", "CurrentUser")
$OriginalPolicies = @{}

foreach ($Scope in $Scopes) {
    try {
        $OriginalPolicies[$Scope] = Get-ExecutionPolicy -Scope $Scope
    } catch {
        Write-Warning "Could not retrieve execution policy for scope: $Scope"
    }
}

Write-Host "[*] Setting ExecutionPolicy to Bypass..."
foreach ($Scope in $Scopes) {
    Set-ExecutionPolicy Bypass -Scope $Scope -Force
}

# Run master script
Write-Host "[*] Running master.ps1 with arguments: $($MasterArgs -join ' ')"
& .\master.ps1 @MasterArgs

# Restore policies
Write-Host "[*] Restoring ExecutionPolicy..."
foreach ($Scope in $Scopes) {
    if ($OriginalPolicies.ContainsKey($Scope)) {
        Set-ExecutionPolicy $OriginalPolicies[$Scope] -Scope $Scope -Force
    }
}

Write-Host "[+] Done."
