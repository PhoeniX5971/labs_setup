param(
	[Parameter(Mandatory = $true)]
	[string]$PackageName,

	[double]$RequiredGB = 0.5
)

# Colors for output
function Info($msg)
{ Write-Host "[*] $msg" -ForegroundColor Yellow 
}
function Success($msg)
{ Write-Host "[+] $msg" -ForegroundColor Green 
}
function ErrorMsg($msg)
{ Write-Host "[-] $msg" -ForegroundColor Red 
}
function Warn($msg)
{ Write-Host "[!] $msg" -ForegroundColor Magenta 
}

# Check Size Before Install
try
{
	. ./size_check.ps1 -RequiredGB $RequiredGB -Drive "C"
} catch
{
	ErrorMsg "Installation of $PackageName aborted due to disk space check failure."
	exit 1
}

# Install Package
try
{
	Info "Installing $PackageName..."
	choco install $PackageName -y
	Success "$PackageName installed successfully."
} catch
{
	ErrorMsg "Installation of $PackageName failed."
	exit 1
}
