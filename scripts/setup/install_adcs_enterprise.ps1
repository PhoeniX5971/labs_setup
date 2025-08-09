#############################################
#  INSTALL ENTERPRISE ROOT CA & MODULES     #
#############################################
# Requires:
# - Windows Server (domain-joined)
# - Domain Admin or Enterprise Admin rights
# - PowerShell run as Administrator
#
# This installs Active Directory Certificate Services (AD CS)
# as an Enterprise Root Certification Authority and sets up the
# ADCSTemplate PowerShell module for managing certificate templates.
#
# Notes:
# - Enterprise CA is required for certificate templates
# - These commands should be run only in a test/lab environment
#

#############################################
#  Step 1: Install Enterprise Root CA       #
#############################################

# Install role (includes management tools)
Install-WindowsFeature Adcs-Cert-Authority -IncludeManagementTools

# Configure a new Enterprise Root CA (interactive / supply params)
Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -Force

#############################################
#  Step 2: Install ADCSTemplate Module      #
#############################################

# On a machine that has AD PowerShell modules and is domain joined
Install-Module -Name ADCSTemplate -Scope AllUsers -Force
Import-Module ADCSTemplate
