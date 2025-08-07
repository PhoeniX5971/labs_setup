# PowerShell Active Directory Toolkit

A modular collection of PowerShell scripts for Active Directory enumeration, abuse, and setup automation in Windows Server environments.

---

## Overview

This toolkit includes scripts for common Active Directory privilege escalation techniques, domain controller setup, and Windows configuration tasks. It is designed to be used on domain-joined Windows machines with appropriate permissions.

All scripts can be invoked individually or via a central **master** script that accepts parameters to run specific modules.

---

## Scripts

### master.ps1

A master controller script to invoke any of the available modules with parameters.

**Parameters:**

| Parameter                  | Type   | Description                                                         |
| -------------------------- | ------ | ------------------------------------------------------------------- |
| `-AddSPN`                  | Switch | Add Service Principal Name (SPN) to a user (Kerberoasting)          |
| `-DisableFirewall`         | Switch | Disable all Windows Firewall profiles                               |
| `-EnableASREP`             | Switch | Enable AS-REP Roasting by disabling pre-authentication for a user   |
| `-UnconstrainedDelegation` | Switch | Enable unconstrained delegation on a user account                   |
| `-SetupAD`                 | Switch | Install AD DS role and promote machine to Domain Controller         |
| `-ACLAbuse`                | Switch | Abuse ACLs to grant GenericAll permissions from one user to another |

**Shared parameters:**

| Parameter               | Type   | Used By                                            |
| ----------------------- | ------ | -------------------------------------------------- |
| `-UserIdentity`         | String | `AddSPN`, `EnableASREP`, `UnconstrainedDelegation` |
| `-ServicePrincipalName` | String | `AddSPN`                                           |
| `-TargetUser`           | String | `ACLAbuse`                                         |
| `-LowPrivUser`          | String | `ACLAbuse`                                         |
| `-DomainName`           | String | `SetupAD`                                          |
| `-NetBIOSName`          | String | `SetupAD`                                          |

---

### run_with_bypass.ps1

A helper wrapper script that temporarily sets the PowerShell execution policy to **Bypass** for both LocalMachine and CurrentUser scopes, runs `master.ps1` with given arguments, then restores the original policies.

This ensures scripts can run on machines where execution policies are restrictive without permanently changing system settings.

---

### add_spn_for_kerberosting.ps1

Adds a Service Principal Name (SPN) to a specified user account.

- Used for Kerberoasting attacks by enabling targeted Kerberos ticket requests.

**Parameters:**

- `-UserIdentity` (string, mandatory): Target AD user.
- `-ServicePrincipalName` (string, mandatory): SPN string to add (e.g., `MSSQLSvc/sql.srv.local:1433`).

---

### disable_firewall.ps1

Disables Windows Firewall for all profiles (Domain, Public, Private).

Useful to ease lateral movement or C2 communications during penetration testing.

---

### enable_asrep_roasting.ps1

Disables Kerberos pre-authentication on a specified user account.

Allows extraction of password hashes without user interaction (AS-REP Roasting).

**Parameters:**

- `-UserIdentity` (string, mandatory): Target AD user.

---

### enable_unconstrained_delegation.ps1

Enables unconstrained delegation on a user account.

This allows the user to impersonate other users after authenticating to services hosted by this account.

**Parameters:**

- `-UserIdentity` (string, mandatory): Target AD user.

---

### setup_ad_for_win_server.ps1

Installs Active Directory Domain Services role and promotes the machine to a domain controller.

Prompts for Directory Services Restore Mode (DSRM) password interactively.

**Parameters:**

- `-DomainName` (string, mandatory): Fully qualified domain name (e.g., `corp.local`).
- `-NetBIOSName` (string, mandatory): NetBIOS domain name (e.g., `CORP`).

---

### weak_perms_on_user.ps1

Abuses ACLs by granting `GenericAll` permissions from a low privilege user to a target user.

Used to escalate privileges by taking control of highly privileged accounts.

**Parameters:**

- `-TargetUser` (string, mandatory): The user to grant permissions on (e.g., `domainadmin`).
- `-LowPrivUser` (string, mandatory): The low privilege user to be granted permissions.

---

## Why `run_with_bypass.ps1`?

Many Windows environments enforce **PowerShell Execution Policies** that restrict running scripts by default. The `run_with_bypass.ps1` wrapper temporarily sets the execution policy to **Bypass** for the current session and user/machine scopes, allowing your scripts to execute without permanently altering security settings.

This is safer for testing or running on machines where policy changes are restricted or monitored.

---

## Usage Examples

```powershell
# Add SPN for kerberoasting
.\master.ps1 -AddSPN -UserIdentity "svc-sql" -ServicePrincipalName "MSSQLSvc/sql.srv.local:1433"

# Disable firewall
.\master.ps1 -DisableFirewall

# Enable AS-REP roasting on a user
.\master.ps1 -EnableASREP -UserIdentity "user.noauth"

# Enable unconstrained delegation
.\master.ps1 -UnconstrainedDelegation -UserIdentity "target.user"

# Setup a new AD domain controller
.\master.ps1 -SetupAD -DomainName "corp.local" -NetBIOSName "CORP"

# Abuse ACLs to escalate privileges
.\master.ps1 -ACLAbuse -TargetUser "domainadmin" -LowPrivUser "low.priv"

# Run master script with execution policy bypass
.\run_with_bypass.ps1 -MasterArgs @("-AddSPN", "-UserIdentity", "svc-sql", "-ServicePrincipalName", "MSSQLSvc/sql.srv.local:1433")
```

---

## Requirements

- Windows Server (for AD setup script).
- PowerShell running as Administrator.
- ActiveDirectory PowerShell module installed.
- Domain-joined machine (except for firewall script).
- Proper permissions depending on action (e.g., GenericWrite for SPN addition).
