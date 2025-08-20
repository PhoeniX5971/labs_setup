param(
	[Parameter(Mandatory = $true)]
	[string]$FleetServer,         # Fleet Server URL, e.g., http://172.16.31.132:8220

	[Parameter(Mandatory = $true)]
	[string]$EnrollmentToken,     # Enrollment token from Kibana (api_key)

	[Parameter(Mandatory = $true)]
	[string]$PolicyID             # Agent policy ID (for info only)
)

# -----------------------------
# Output helpers
# -----------------------------
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

# -----------------------------
# Download Elastic Agent MSI
# -----------------------------
$MSIPath = "$env:TEMP\elastic-agent.msi"
$DownloadURL = "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-9.1.2-windows-x86_64.msi"

Info "Downloading Elastic Agent MSI..."
try
{
	Invoke-WebRequest -Uri $DownloadURL -OutFile $MSIPath
	Success "Downloaded MSI to $MSIPath"
} catch
{
	ErrorMsg "Failed to download MSI: $_"
	exit 1
}

# -----------------------------
# Install Elastic Agent
# -----------------------------
Info "Installing Elastic Agent..."
$msiArgs = "/i `"$MSIPath`" /qn FLEET_ENROLL=1 FLEET_URL=`"$FleetServer`" FLEET_ENROLLMENT_TOKEN=`"$EnrollmentToken`""
try
{
	Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -NoNewWindow
	Success "Elastic Agent installed successfully!"
} catch
{
	ErrorMsg "Failed to install Elastic Agent: $_"
	exit 1
}

# -----------------------------
# Cleanup
# -----------------------------
Info "Cleaning up..."
try
{
	Remove-Item $MSIPath -Force
	Success "Removed temporary MSI file."
} catch
{
	Warn "Failed to remove MSI file. You can delete it manually: $MSIPath"
}

# -----------------------------
# Done
# -----------------------------
Success "Agent enrolled under policy: $PolicyID"
