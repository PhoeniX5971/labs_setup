<#
.SYNOPSIS
Lab-safe demonstration of launching a webshell on a vulnerable SMBv1 host.

.DESCRIPTION
This script pairs with a lab SMBv1-vulnerable host (MS17-010) to simulate a remote code execution attack.  
It **does not exploit real vulnerabilities**—instead, it demonstrates the steps an attacker would take in a controlled lab.

.EXAMPLE
PS> .\attack_smbv1_webshell.ps1 -Target 192.168.1.10
Simulates deploying a webshell on the target host in a lab environment.
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$TargetHost
)

function Invoke-WebshellSimulation
{
	param($TargetHost)
	Write-Host "[*] Connecting to vulnerable SMBv1 host at $TargetHost..." -ForegroundColor Cyan
	Start-Sleep -Seconds 1

	# Simulate checking MS17-010
	Write-Host "[+] Target appears vulnerable to MS17-010 (lab simulation)." -ForegroundColor Green
	Start-Sleep -Seconds 1

	# Simulate writing a webshell
	Write-Host "[*] Deploying webshell to target..." -ForegroundColor Cyan
	Start-Sleep -Seconds 1

	# Fake shell interaction
	Write-Host "[SUCCESS] Webshell deployed! Launching simulated shell session..." -ForegroundColor Green
	Write-Host ""
	Write-Host "================ Simulated Webshell =================" -ForegroundColor Yellow
	Write-Host "You are now connected to $TargetHost (simulated shell)." -ForegroundColor Yellow
	Write-Host "Type 'exit' to leave." -ForegroundColor Yellow

	while ($true)
	{
		$cmd = Read-Host -Prompt "PS $TargetHost>"
		if ($cmd -eq "exit")
		{
			Write-Host "[*] Closing simulated webshell..." -ForegroundColor Cyan
			break
		} else
		{
			# Simulate command output
			Write-Host "[simulated output] $cmd executed successfully." -ForegroundColor Magenta
		}
	}
}

# Main
Invoke-WebshellSimulation -TargetHost $TargetHost
