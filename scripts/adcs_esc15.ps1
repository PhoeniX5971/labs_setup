#############################################
#  ESC15: Grant Enroll Permission to Group  #
#############################################
# Requires:
# - Admin privileges on CA server
# - ADCSTemplate PowerShell module installed
#
# This script grants Enroll permissions on a certificate template
# to a specified Active Directory group, making the template
# vulnerable to unauthorized certificate issuance.

param(
    [Parameter(Mandatory=$true)]
    [string]$TemplateName = "Web Server",

    [Parameter(Mandatory=$true)]
    [string]$GroupName = "Domain Users"
)

# Import ADCSTemplate module (make sure it's installed)
Import-Module ADCSTemplate -ErrorAction Stop

Write-Host "[*] Setting Enroll permission on template '$TemplateName' for group '$GroupName'..."

# Grant Enroll permission
Set-ADCSTemplateACL -DisplayName $TemplateName -Type Allow -Identity $GroupName -Enroll

Write-Host "[+] Enroll permission granted successfully."
