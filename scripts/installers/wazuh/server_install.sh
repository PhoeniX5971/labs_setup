#!/bin/bash

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root. Try: sudo $0 or su -c $0"
	exit 1
fi

# Check if curl is installed
if ! command -v curl >/dev/null 2>&1; then
	echo "curl not found, installing..."
	if command -v apt >/dev/null 2>&1; then
		apt update -y && apt install -y curl
	elif command -v yum >/dev/null 2>&1; then
		yum install -y curl
	elif command -v dnf >/dev/null 2>&1; then
		dnf install -y curl
	else
		echo "No supported package manager found. Please install curl manually."
		exit 1
	fi
else
	echo "curl is already installed."
fi

# Check if Wazuh is already installed
if [ -x "/var/ossec/bin/wazuh-control" ]; then
	echo "Wazuh is already installed. Skipping installation."
	exit 0
fi

# Download and run Wazuh installer
echo "Downloading and running Wazuh installer..."
curl -sO https://packages.wazuh.com/4.12/wazuh-install.sh
bash ./wazuh-install.sh -a --overwrite

tar -xf wazuh-install-files.tar --strip-components=1 -C . wazuh-install-files/wazuh-passwords.txt
echo "A copy of the passwords file have been moved to current location 'wazuh-passwords.txt'."
