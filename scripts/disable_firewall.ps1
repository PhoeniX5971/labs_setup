#############################################
#  DISABLE ALL FIREWALL PROFILES            #
#############################################
# Requires:
# - Administrator privileges on the local machine
# - PowerShell running with elevated permissions
#
# This command disables the Windows Firewall for all profiles (Domain, Public, Private)
# Often used to make lateral movement or C2 communication easier.

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Usage:
# .\disable_firewall.ps1
