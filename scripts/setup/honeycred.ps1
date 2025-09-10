param (
	[string]$Domain = "WORKGROUP",
	[string]$User,
	[string]$Password
)

# Validate parameters
if (-not $User)
{
	Write-Host "Error: User parameter is required." -ForegroundColor Red
	exit 1
}
if (-not $Password)
{
	Write-Host "Error: Password parameter is required." -ForegroundColor Red
	exit 1
}

# Destination folder
$dest = "C:\tmp"
if (-not (Test-Path $dest))
{
	New-Item -Path $dest -ItemType Directory | Out-Null
}

# URLs to download
$files = @(
	"https://github.com/hosom/honeycred/releases/download/v1.0/agent.exe",
	"https://github.com/hosom/honeycred/releases/download/v1.0/honeycred.exe"
)

# Download files
foreach ($url in $files)
{
	$filename = Split-Path $url -Leaf
	$outPath = Join-Path $dest $filename
	Write-Host "Downloading $filename..."
	Invoke-WebRequest -Uri $url -OutFile $outPath
}

# Run honeycred.exe
$honeycredPath = Join-Path $dest "honeycred.exe"
$agentPath = Join-Path $dest "agent.exe"
Write-Host "Running honeycred.exe..."
Start-Process -FilePath $honeycredPath -ArgumentList "-u `"$Domain\$User`" -pw $Password -path $agentPath"
Write-Host "Done."
