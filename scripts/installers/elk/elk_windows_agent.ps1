param(
	[Parameter(Mandatory = $true)]
	[string]$password,

	[Parameter(Mandatory = $true)]
	[string]$ip
)

# --- Configuration ---
$KibanaURL = "http://$ip:5601"
$ElasticUser = "elastic"
$ElasticPassword = $password
$PolicyID = "fleet-server-policy"

# --- Create Fleet Enrollment Token ---
$body = @{
	policy_id = $PolicyID
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "$KibanaURL/api/fleet/enrollment_api_keys" `
	-Headers @{ "kbn-xsrf" = "true"; "Content-Type" = "application/json" } `
	-Method POST `
	-Body $body `
	-Authentication Basic `
	-Credential (New-Object System.Management.Automation.PSCredential($ElasticUser, (ConvertTo-SecureString $ElasticPassword -AsPlainText -Force)))

$EnrollmentToken = $response.item.api_key

Write-Host "Enrollment token created: $EnrollmentToken"

# --- Agent Installation ---
$ElasticAgentZip = "C:\ElasticAgent\elastic-agent.zip"
$ElasticAgentDir = "C:\ElasticAgent"

if (-Not (Test-Path $ElasticAgentDir))
{
	New-Item -ItemType Directory -Path $ElasticAgentDir | Out-Null
}

Invoke-WebRequest -Uri "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-9.1.2-windows-x86_64.zip" -OutFile $ElasticAgentZip
Expand-Archive -Force $ElasticAgentZip -DestinationPath $ElasticAgentDir
Set-Location "$ElasticAgentDir\elastic-agent-9.1.2-windows-x86_64"

# Install & enroll Elastic Agent
.\elastic-agent.exe install `
	--url "http://$ip:8220" `
	--enrollment-token $EnrollmentToken `
	--insecure `
	-n `
	-f
