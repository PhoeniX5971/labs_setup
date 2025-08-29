<#
.SYNOPSIS
    Enables NetBIOS over TCP/IP (NetBIOS Name Service) for all network interfaces.

.DESCRIPTION
    This script sets the registry value 'NetbiosOptions' to 1 under
    HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces\<Interface>
    for each interface. It verifies that the change was applied successfully and exits with code 1 if it fails.

.PARAMETER Value
    Value to set for NetbiosOptions (0 = Default, 1 = Enable, 2 = Disable). Default is 1 (Enable).

.EXAMPLE
    PS> .\Enable-NBNS.ps1 -Value 1

.NOTES
    Author: phoenix
#>

param(
	[Parameter(Mandatory=$false)]
	[ValidateSet(0,1,2)]
	[int]$Value = 1
)

$regKeyBase = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces"

try
{
	# Enumerate interfaces
	$interfaces = Get-ChildItem -Path $regKeyBase
	if (-not $interfaces)
	{
		Write-Error "[!] No interfaces found under $regKeyBase"
		exit 1
	}

	foreach ($iface in $interfaces)
	{
		$ifacePath = Join-Path $regKeyBase $iface.PSChildName
		Write-Host "[*] Setting NetbiosOptions for interface '$($iface.PSChildName)' to $Value..." -ForegroundColor Cyan
		Set-ItemProperty -Path $ifacePath -Name "NetbiosOptions" -Value $Value -Verbose
	}

	# Verification
	$failed = $false
	foreach ($iface in $interfaces)
	{
		$ifacePath = Join-Path $regKeyBase $iface.PSChildName
		$current = Get-ItemProperty -Path $ifacePath -Name "NetbiosOptions"
		if ($current.NetbiosOptions -ne $Value)
		{
			Write-Error "[!] Verification failed for interface '$($iface.PSChildName)': NetbiosOptions = $($current.NetbiosOptions)"
			$failed = $true
		} else
		{
			Write-Host "[+] Verification passed for interface '$($iface.PSChildName)'" -ForegroundColor Green
		}
	}

	if ($failed)
	{ exit 1 
	} else
	{ exit 0 
	}

} catch
{
	Write-Error "[!] Failed to set NetbiosOptions: $_"
	exit 1
}
