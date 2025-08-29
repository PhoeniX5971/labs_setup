<#
.SYNOPSIS
    Creates a scheduled task that mounts a network share repeatedly.

.DESCRIPTION
    This script dynamically registers a scheduled task to mount a PSDrive from a UNC path
    using specified credentials. It removes existing tasks with the same name and verifies
    that the new task exists. Exits with code 1 if creation or verification fails.

.PARAMETER TaskName
    The name of the scheduled task.

.PARAMETER User
    The user account to run the task as (e.g., DOMAIN\User).

.PARAMETER Password
    The password for the user account.

.PARAMETER PSDriveRoot
    The UNC path to mount (e.g., '\\Bravos\private').

.PARAMETER RepeatMinutes
    How often the task should repeat (default: 2 minutes).

.EXAMPLE
    PS> .\Create-ResponderTask.ps1 -TaskName "responder_bot" -User "north.sevenkingdoms.local\robb.stark" `
          -Password "sexywolfy" -PSDriveRoot "\\Bravos\private" -RepeatMinutes 2

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
	[string]$PSDriveRoot,

	[Parameter(Mandatory=$false)]
	[int]$RepeatMinutes = 2
)

try
{
	# Command to run
	$taskCommand = "/c powershell New-PSDrive -Name 'Public' -PSProvider 'FileSystem' -Root '$PSDriveRoot'"

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
	Write-Error "[!] Failed to create task: $_"
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
