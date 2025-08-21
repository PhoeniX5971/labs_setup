param(
	[Parameter(Mandatory = $true)]
	[string]$password,

	[Parameter(Mandatory = $true)]
	[string]$ip
)

# --- Configuration ---
$KibanaURL      = "http://${ip}:5601"
$ElasticUser    = "elastic"
$ElasticPassword = $password
$PolicyID       = "fleet-server-policy"

Write-Host "Using Kibana URL: $KibanaURL"

# --- Create Fleet Enrollment Token ---
$Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${ElasticUser}:${ElasticPassword}"))

Write-Host "Creating Fleet enrollment token..."
$EnrollmentToken = (Invoke-RestMethod `
		-Uri "$KibanaURL/api/fleet/enrollment_api_keys" `
		-Headers @{
		"kbn-xsrf"    = "true"
		"Content-Type" = "application/json"
		"Authorization" = "Basic $Base64AuthInfo"
	} `
		-Method POST `
		-Body (@{ policy_id = $PolicyID } | ConvertTo-Json)
).item.api_key

Write-Host "Enrollment token created: $EnrollmentToken"

# --- Agent Installation ---
$ElasticAgentZip = "C:\ElasticAgent\elastic-agent.zip"
$ElasticAgentDir = "C:\ElasticAgent"

if (-Not (Test-Path $ElasticAgentDir))
{
	New-Item -ItemType Directory -Path $ElasticAgentDir | Out-Null
}

# Only download if zip doesn't exist
if (-Not (Test-Path $ElasticAgentZip))
{
	Write-Host "Downloading Elastic Agent zip..."
	Invoke-WebRequest -Uri "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-9.1.2-windows-x86_64.zip" -OutFile $ElasticAgentZip
} else
{
	Write-Host "Elastic Agent zip already exists. Skipping download."
}

Write-Host "Extracting Elastic Agent..."
Expand-Archive -Force $ElasticAgentZip -DestinationPath $ElasticAgentDir

$AgentPath = Join-Path $ElasticAgentDir "elastic-agent-9.1.2-windows-x86_64"
Set-Location $AgentPath

# --- Install & enroll Elastic Agent ---
$AgentExe = Join-Path $AgentPath "elastic-agent.exe"
$AgentArgs = @(
	"install"
	"--url", "http://${ip}:8220"
	"--enrollment-token", $EnrollmentToken
	"--insecure"
	"-n"
	"-f"
)

Write-Host "Installing and enrolling Elastic Agent..."
& $AgentExe @AgentArgs

Write-Host "Elastic Agent installation complete."
