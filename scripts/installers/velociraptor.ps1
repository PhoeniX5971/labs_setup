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
	. ./size_check.ps1 -RequiredGB 0.25 -Drive "C"
} catch
{
	ErrorMsg "Installation aborted due to disk space check failure."
	exit 1
}

# Step 1: Fetch latest Velociraptor release from GitHub
Info "Fetching Velociraptor latest release info..."
try
{
	# Ensure TLS 1.2 for GitHub API on older Windows builds
	try
	{ [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
	} catch
	{
	}

	$headers = @{
		'User-Agent' = 'phoenix-velociraptor-installer'
		'Accept'     = 'application/vnd.github+json'
	}

	$release = Invoke-RestMethod -Uri "https://api.github.com/repos/Velocidex/velociraptor/releases/latest" -Headers $headers

	if (-not $release.assets)
	{ throw "No assets found in the latest release." 
	}

	$asset = $release.assets |
		Where-Object { $_.name -like "*windows-amd64.msi" } |
		Sort-Object name -Descending |
		Select-Object -First 1

	if (-not $asset)
	{ throw "No Windows x64 MSI asset found." 
	}

	$downloadUrl = $asset.browser_download_url
	if (-not $downloadUrl)
	{ throw "Asset has no download URL." 
	}

	# Extract version from filename (e.g., velociraptor-v0.74.5-windows-amd64.msi → 0.74.5)
	if ($asset.name -match 'velociraptor-v([\d\.]+)-windows-amd64\.msi')
	{
		$version = $matches[1]
	} else
	{
		# Fallback to tag (strip leading v)
		$version = ($release.tag_name -replace '^v','')
	}

	Success "Found Velociraptor version $version"
	Info "Download URL: $downloadUrl"
} catch
{
	ErrorMsg "Failed to fetch Velociraptor release info. $($_.Exception.Message)"
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
