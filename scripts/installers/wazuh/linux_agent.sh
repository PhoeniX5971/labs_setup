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

# Install PGP keys and repo
echo "[*] Installing PGP keys and adding repo..."
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
apt-get update -y
echo "[+] Repository added and packages updated."

# Install the agent
echo "[*] Installing wazuh-agent..."
apt-get install -y wazuh-agent
echo "[+] Wazuh agent installed."

# Ensure correct server block in config
echo "[*] Configuring server and agent name..."
CONFIG_FILE="/var/ossec/etc/ossec.conf"
# Backup first
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Add or replace server IP
if grep -q "<server>" "$CONFIG_FILE"; then
	sed -i "s|<address>.*</address>|<address>$WAZUH_MANAGER</address>|" "$CONFIG_FILE"
else
	# insert server block under <client> tag
	sed -i "/<client>/a \ \ <server>\n\ \ \ \ <address>$WAZUH_MANAGER</address>\n\ \ </server>" "$CONFIG_FILE"
fi

# Set agent name
sed -i "s|<node_name>.*</node_name>|<node_name>${AGENT_NAME}</node_name>|" "$CONFIG_FILE"
echo "[+] Server and agent name configured."

# Register agent and restart service
echo "[*] Registering agent with manager..."
agent-auth -m "$WAZUH_MANAGER" -A "$AGENT_NAME"
systemctl enable wazuh-agent
systemctl restart wazuh-agent
echo "[+] Agent registered and restarted."

# Summary
echo "=================================="
echo "[+] Wazuh agent installation complete"
echo "    Manager: $WAZUH_MANAGER"
echo "    Agent name: $AGENT_NAME"
echo "=================================="
