#!/bin/bash

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
	echo "[!] This script must be run as root. Try: sudo $0 or su -c $0"
	exit 1
fi

# Default values
WAZUH_MANAGER=""
AGENT_NAME="$(hostname)" # fallback to hostname if not given

# Parse arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	-Manager)
		WAZUH_MANAGER="$2"
		shift 2
		;;
	-AgentName)
		AGENT_NAME="$2"
		shift 2
		;;
	*)
		echo "[!] Unknown option: $1"
		echo "[-] Usage: $0 -Manager <IP/Hostname> [-AgentName <Name>]"
		exit 1
		;;
	esac
done

# Validate required parameter
if [[ -z "$WAZUH_MANAGER" ]]; then
	echo "[!] Error: -Manager is required"
	echo "[-] Usage: $0 -Manager <IP/Hostname> [-AgentName <Name>]"
	exit 1
fi

# Check if curl is installed
if ! command -v curl >/dev/null 2>&1; then
	echo "[*] curl not found, installing..."
	apt update -y && apt install -y curl
	echo "[+] curl installed successfully."
else
	echo "[-] curl is already installed."
fi

# Download and run Wazuh installer
echo "[*] Installing PGP keys..."
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg
echo "[+] PGP keys installed."

# Add the repository
echo "[*] Adding Wazuh repository..."
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
echo "[+] Repository added."

# Update system packages
echo "[*] Updating apt packages..."
apt-get update -y
echo "[+] Packages updated."

# Install the agent with manager address
echo "[*] Installing wazuh-agent..."
WAZUH_MANAGER="$WAZUH_MANAGER" apt-get install -y wazuh-agent
echo "[+] Wazuh agent installed."

# Configure agent name
echo "[*] Configuring agent name..."
sed -i "s|<node_name>.*</node_name>|<node_name>${AGENT_NAME}</node_name>|" /var/ossec/etc/ossec.conf
echo "[+] Agent name set to '${AGENT_NAME}'."

# Restart service
echo "[*] Registering agent with manager..."
agent-auth -m "$WAZUH_MANAGER" -A "$AGENT_NAME"
systemctl restart wazuh-agent
echo "[+] Agent registered and restarted."

# Summary
echo "=================================="
echo "[+] Wazuh agent installation complete"
echo "    Manager: $WAZUH_MANAGER"
echo "    Agent name: $AGENT_NAME"
echo "=================================="
