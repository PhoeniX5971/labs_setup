#!/bin/bash
set -euo pipefail

# Default values
INSTALL_DIR="/opt/velociraptor"
ADMIN_USER="admin"
ADMIN_PASSWORD="changeme"

# Parse named arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	-dir | --dir)
		INSTALL_DIR="$2"
		shift 2
		;;
	-username | --username)
		ADMIN_USER="$2"
		shift 2
		;;
	-password | --password)
		ADMIN_PASSWORD="$2"
		shift 2
		;;
	*)
		echo "Unknown argument: $1"
		echo "Usage: $0 -dir <install_dir> -username <admin_user> -password <admin_password>"
		exit 1
		;;
	esac
done

echo "[*] Fetching latest Velociraptor release tag..."
LATEST_TAG=$(curl -s "https://api.github.com/repos/Velocidex/velociraptor/releases/latest" | grep -Po '"tag_name": *"\K.*?(?=")')
echo "[+] Latest version: ${LATEST_TAG}"

FILENAME="velociraptor-${LATEST_TAG}-linux-amd64"
DOWNLOAD_URL="https://github.com/Velocidex/velociraptor/releases/download/${LATEST_TAG}/${FILENAME}"

echo "[*] Downloading Velociraptor from ${DOWNLOAD_URL}..."
curl -L -o "${FILENAME}" "${DOWNLOAD_URL}"

echo "[*] Making Velociraptor executable..."
chmod +x "${FILENAME}"

echo "[*] Verifying executable..."
if [ -x "./${FILENAME}" ]; then
	echo "[+] ${FILENAME} is executable"
else
	echo "[-] ${FILENAME} is not executable"
	exit 1
fi

echo "[*] Creating installation directory at ${INSTALL_DIR}..."
sudo mkdir -p "$INSTALL_DIR"

# Generate the server configuration file (non-interactive)
echo "[*] Generating server configuration..."
sudo ./"${FILENAME}" config generate \
	--server \
	--non-interactive \
	--config "${INSTALL_DIR}/velociraptor.config.yaml" \
	--port 8889 \
	--admin-user "${ADMIN_USER}" \
	--admin-password "${ADMIN_PASSWORD}" \
	--data-dir "${INSTALL_DIR}/data"

echo "[+] Velociraptor server configuration generated successfully."
