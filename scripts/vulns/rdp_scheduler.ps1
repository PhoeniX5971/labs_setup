<#
.SYNOPSIS
    Registers a scheduled task to repeatedly execute a PowerShell RDP bot script.

.DESCRIPTION
    This script dynamically creates a scheduled task to run a specified PowerShell script
    repeatedly under a given user account. Existing tasks with the same name are removed.
    Verification ensures the task exists, and the script exits with code 1 on failure.

.PARAMETER TaskName
    Name of the scheduled task.

.PARAMETER User
    User account to run the task under (DOMAIN\User).

.PARAMETER Password
    Password for the user account.

.PARAMETER ScriptPath
    Full path to the PowerShell script to execute.

.PARAMETER RepeatMinutes
    How often the task should repeat (default: 1 minute).

.EXAMPLE
    PS> .\RDP-Scheduler.ps1 -TaskName "connect_bot" -User "north\robb.stark" `
          -Password "sexywolfy" -ScriptPath "c:\setup\bot_rdp.ps1" -RepeatMinutes 1

.NOTES
    Author: phoenix
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$TaskName,

	[Parameter(Mandatory=$true)]
	[string]$User,

	[Parameter(Mandatory=$true)]
	[string]$Password,

	[Parameter(Mandatory=$true)]
	[string]$ScriptPath,

	[Parameter(Mandatory=$false)]
	[int]$RepeatMinutes = 1
)

try
{
	# Define task command
	$taskCommand = "/c powershell $ScriptPath"

	# Define scheduled task components
	$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument $taskCommand
	$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $RepeatMinutes)
	$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
		-DontStopIfGoingOnBatteries `
		-StartWhenAvailable `
		-RunOnlyIfNetworkAvailable `
		-DontStopOnIdleEnd

	# Remove existing task
	$existingTask = Get-ScheduledTask | Where-Object {$_.TaskName -eq $TaskName}
	if ($existingTask)
	{
		Write-Host "[*] Task '$TaskName' exists. Removing..." -ForegroundColor Cyan
		Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
	}

	# Register new task
	Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -User $User -Password $Password -Settings $settings
	Write-Host "[+] Task '$TaskName' registered successfully." -ForegroundColor Green

} catch
{
	Write-Error "[!] Failed to create scheduled task: $_"
	exit 1
}

# Verification
try
{
	$taskCheck = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
	if ($taskCheck)
	{
		Write-Host "[+] Verification passed: Task '$TaskName' exists." -ForegroundColor Green
		exit 0
	} else
	{
		Write-Error "[!] Verification failed: Task '$TaskName' does not exist."
		exit 1
	}
} catch
{
	Write-Error "[!] Verification error: $_"
	exit 1
}
