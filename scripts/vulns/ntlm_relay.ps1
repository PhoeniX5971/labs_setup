<#
.SYNOPSIS
    Creates a scheduled task to mount a remote filesystem repeatedly (NTLM relay style).

.DESCRIPTION
    This script dynamically registers a scheduled task on the local machine to run a PowerShell command
    (e.g., mounting a network drive). If the task already exists, it will be unregistered first.
    The script verifies that the task was successfully created and exits with code 1 if any step fails.

.PARAMETER TaskName
    The name of the scheduled task.

.PARAMETER User
    The account under which the task should run (e.g., 'DOMAIN\User').

.PARAMETER Password
    The password of the user account.

.PARAMETER PSDriveRoot
    The UNC path or local path for the PSDrive (e.g., '\\Meren\Private').

.PARAMETER RepeatMinutes
    How often the task should repeat (default: 5 minutes).

.EXAMPLE
    PS> .\Create-NTLMRelayTask.ps1 -TaskName "ntlm_bot" -User "north.sevenkingdoms.local\eddard.stark" `
          -Password "FightP3aceAndHonor!" -PSDriveRoot "\\Meren\Private" -RepeatMinutes 5

.NOTES
    Author: phoenix
    Requires: PowerShell 5+ (ScheduledTasks module)
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$TaskName,

	[Parameter(Mandatory=$true)]
	[string]$User,

	[Parameter(Mandatory=$true)]
	[string]$Password,

	[Parameter(Mandatory=$true)]
	[string]$PSDriveRoot,

	[Parameter(Mandatory=$false)]
	[int]$RepeatMinutes = 5
)

try
{
	# Define task command
	$taskCommand = "/c powershell New-PSDrive -Name 'Public' -PSProvider 'FileSystem' -Root '$PSDriveRoot'"

	# Define task action
	$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument $taskCommand

	# Define task trigger
	$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $RepeatMinutes)

	# Define task settings
	$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
		-DontStopIfGoingOnBatteries `
		-StartWhenAvailable `
		-RunOnlyIfNetworkAvailable `
		-DontStopOnIdleEnd

	# Remove existing task if it exists
	$existingTask = Get-ScheduledTask | Where-Object {$_.TaskName -eq $TaskName}
	if ($existingTask)
	{
		Write-Host "[*] Task '$TaskName' already exists. Removing..." -ForegroundColor Cyan
		Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
	}

	# Register the new scheduled task
	Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -User $User -Password $Password -Settings $settings
	Write-Host "[+] Scheduled task '$TaskName' registered successfully." -ForegroundColor Green

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
