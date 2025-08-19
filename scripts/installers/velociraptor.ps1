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

# Step 1: Fetch latest Velociraptor release from GitHub
Info "Fetching Velociraptor latest release info..."
try
{
	$asset = $release.assets | Where-Object { $_.name -like "*windows-amd64.msi" } |
		Sort-Object name -Descending |
		Select-Object -First 1
	$downloadUrl = $asset.browser_download_url

	# Extract version from filename (e.g., velociraptor-v0.74.5-windows-amd64.msi → 0.74.5)
	if ($asset.name -match 'velociraptor-v([\d\.]+)-windows-amd64\.msi')
	{
		$version = $matches[1]
	} else
	{
		$version = $release.tag_name
	}

	Success "Found Velociraptor version $version"
	Info "Download URL: $downloadUrl"
} catch
{
	ErrorMsg "Failed to fetch Velociraptor release info."
	exit 1
}

# Step 2: Download MSI
$msiPath = "$PSScriptRoot\velociraptor-latest.msi"
Info "Downloading Velociraptor MSI..."
try
{
	Invoke-WebRequest -Uri $downloadUrl -OutFile $msiPath
	Success "Velociraptor downloaded to $msiPath"
} catch
{
	ErrorMsg "Failed to download Velociraptor MSI."
	exit 1
}

# Step 3: Install silently
Info "Installing Velociraptor silently..."
$process = Start-Process "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -PassThru
if ($process.ExitCode -eq 0)
{
	Success "Velociraptor installation completed."
	Remove-Item $msiPath -Force
} else
{
	ErrorMsg "Velociraptor installation failed with exit code $($process.ExitCode)."
	exit 1
}

# Step 4: Start Velociraptor service
Info "Starting Velociraptor service..."
try
{
	Start-Service "Velociraptor"
	Success "Velociraptor service started."
} catch
{
	Warn "Could not start Velociraptor service. It may already be running."
}
