param(
	[Parameter(Mandatory=$true)]
	[string]$Username,

	[Parameter(Mandatory=$true)]
	[String]$Password,

	[string]$FullName = "",
	[string]$Description = "",

	[switch]$Admin
)

# Create the user
New-LocalUser -Name $Username -Password $Password -FullName $FullName -Description $Description
Write-Host "Created local user '$Username'."

# Optionally add to Administrators group
if ($Admin)
{
	Add-LocalGroupMember -Group "Administrators" -Member $Username
	Write-Host "User '$Username' has been added to the Administrators group."
} else
{
	Write-Host "User '$Username' created as a standard user."
}
