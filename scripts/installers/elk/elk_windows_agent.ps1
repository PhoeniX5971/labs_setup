param(
	[Parameter(Mandatory = $true)]
	[string]$password,

	[Parameter(Mandatory = $true)]
	[string]$ipaddr
)

# --- Configuration ---
Write-Host "$ip"
$KibanaURL = [string]"http://$ipaddr:5601"
Write-Host "Using Kibana URL: $KibanaURL"

$ElasticUser = "elastic"
$ElasticPassword = $password
$PolicyID = "fleet-server-policy"

# --- Create Fleet Enrollment Token ---
$body = @{ policy_id = $PolicyID } | ConvertTo-Json

# Encode credentials for Basic Auth
$Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${ElasticUser}:${ElasticPassword}"))

Write-Host "Creating Fleet enrollment token..."
try
{
	$response = Invoke-RestMethod -Uri "$KibanaURL/api/fleet/enrollment_api_keys" `
		-Headers @{
		"kbn-xsrf"    = "true"
		"Content-Type" = "application/json"
		"Authorization" = "Basic $Base64AuthInfo"
	} `
		-Method POST `
		-Body $body

	$EnrollmentToken = $response.item.api_key
	Write-Host "Enrollment token created: $EnrollmentToken"
} catch
{
	Write-Error "Failed to create enrollment token: $_"
	exit 1
}

# --- Agent Installation ---
$ElasticAgentZip = "C:\ElasticAgent\elastic-agent.zip"
$ElasticAgentDir = "C:\ElasticAgent"

if (-Not (Test-Path $ElasticAgentDir))
{
	New-Item -ItemType Directory -Path $ElasticAgentDir | Out-Null
}

Write-Host "Downloading Elastic Agent..."
Invoke-WebRequest -Uri "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-9.1.2-windows-x86_64.zip" -OutFile $ElasticAgentZip

Write-Host "Extracting Elastic Agent..."
Expand-Archive -Force $ElasticAgentZip -DestinationPath $ElasticAgentDir

$AgentPath = Join-Path $ElasticAgentDir "elastic-agent-9.1.2-windows-x86_64"
Set-Location $AgentPath

# --- Install & Enroll Agent ---
$AgentExe = Join-Path $AgentPath "elastic-agent.exe"
$AgentArgs = @(
	"install"
	"--url", "http://$ipaddr:8220"
	"--enrollment-token", $EnrollmentToken
	"--insecure"
	"-n"
	"-f"
)

Write-Host "Installing and enrolling Elastic Agent..."
& $AgentExe @AgentArgs

Write-Host "Elastic Agent installation complete."
