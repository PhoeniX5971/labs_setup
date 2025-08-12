# Colors for output
function Info($msg)   { Write-Host "[*] $msg" -ForegroundColor Yellow }
function Success($msg){ Write-Host "[+] $msg" -ForegroundColor Green }
function ErrorMsg($msg){ Write-Host "[-] $msg" -ForegroundColor Red }
function Warn($msg)   { Write-Host "[!] $msg" -ForegroundColor Magenta }

# Minimum free space in GB required
$requiredGB = 0.5

# Get free space on C: (in GB)
$freeGB = [math]::Round((Get-PSDrive C).Free / 1GB, 2)

if ($freeGB -lt $requiredGB) {
    Write-Host "[-] Not enough disk space. Required: ${requiredGB}GB, Available: ${freeGB}GB" -ForegroundColor Red
    exit 1
} else {
    Write-Host "[+] Disk space check passed. Available: ${freeGB}GB" -ForegroundColor Green
}

# Step 1: Get HTML and extract latest MSI info
Info "Fetching Nessus download page..."
try {
    $html = Invoke-WebRequest -Uri "https://www.tenable.com/downloads/nessus?loginAttempted=true" -UseBasicParsing
    $content = $html.Content
} catch {
    ErrorMsg "Failed to fetch Nessus download page."
    exit 1
}

if ($content -match 'Nessus-(\d+\.\d+\.\d+)-x64\.msi') {
    $version = $matches[1]
    $fileName = $matches[0]
    $downloadUrl = "https://www.tenable.com/downloads/api/v2/pages/nessus/files/$fileName"
    Success "Found latest Nessus version: $version"
    Info "Download URL: $downloadUrl"
} else {
    ErrorMsg "Could not find MSI in HTML."
    exit 1
}

# Step 2: Download MSI
$msiPath = "$PSScriptRoot\$fileName"
Info "Downloading Nessus installer..."
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $msiPath
    Success "Nessus downloaded to $msiPath"
} catch {
    ErrorMsg "Failed to download Nessus MSI."
    exit 1
}

# Step 3: Install silently
Info "Installing Nessus silently..."
$process = Start-Process "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -PassThru
if ($process.ExitCode -eq 0) {
    Success "Nessus installation completed."
    Info "Cleaning up installer file..."
    Remove-Item $msiPath -Force
    Success "Installer removed."
} else {
    ErrorMsg "Nessus installation failed with exit code $($process.ExitCode)."
    exit 1
}

# Step 4: Start Nessus service
Info "Starting Nessus service..."
try {
    Start-Service "Tenable Nessus"
    Success "Nessus service started."
} catch {
    Warn "Could not start Nessus service. It may already be running."
}

# Step 5: Open Nessus in browser
Info "Opening Nessus web interface..."
Start-Process "https://localhost:8834/"
