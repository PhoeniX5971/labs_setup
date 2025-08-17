param(
	[Parameter(Mandatory = $true)]
	[string]$ManagerIP,

	[Parameter(Mandatory = $true)]
	[string]$AgentName
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

$PackageName = "wazuh-agent"

# Install Wazuh Agent
try
{
	Info "Installing $PackageName..."
	$params = "/Manager:$ManagerIP /AgentName:$AgentName"
	choco install $PackageName --params="'$params'" -y
	Success "$PackageName installed successfully on $AgentName pointing to $ManagerIP."
} catch
{
	ErrorMsg "Installation of $PackageName failed."
	exit 1
}
