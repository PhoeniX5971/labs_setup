param(
	[Parameter(Mandatory=$true)]
	[double]$RequiredGB,

	[string]$Drive = "C"
)

# Get free space on specified drive (in GB)
$freeGB = [math]::Round((Get-PSDrive $Drive).Free / 1GB, 2)

if ($freeGB -lt $RequiredGB)
{
	Write-Host "[-] Not enough disk space. Required: ${RequiredGB}GB, Available: ${freeGB}GB" -ForegroundColor Red
	throw "Insufficient disk space."
} else
{
	Write-Host "[+] Disk space check passed. Available: ${freeGB}GB" -ForegroundColor Green
}
