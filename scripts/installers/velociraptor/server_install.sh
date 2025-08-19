#!/bin/bash
set -euo pipefail

# Default values
INSTALL_DIR="/opt/velociraptor"
ADMIN_USER="admin"
ADMIN_PASSWORD="password123"

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

# Fetch latest Linux release asset
echo "[*] Fetching latest Velociraptor release info..."
RELEASE_JSON=$(curl -s https://api.github.com/repos/Velocidex/velociraptor/releases/latest)
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | test("linux-amd64$")) | .browser_download_url' | head -n1)
FILENAME=$(basename "$DOWNLOAD_URL")
VERSION=$(echo "$FILENAME" | grep -Po 'velociraptor-v\K[\d\.]+')
echo "[+] Latest version: $VERSION"
echo "[+] Download URL: $DOWNLOAD_URL"

# Download the binary
echo "[*] Downloading Velociraptor..."
curl -L -o "$FILENAME" "$DOWNLOAD_URL"

# Make executable
chmod +x "$FILENAME"
if [ -x "$FILENAME" ]; then
	echo "[+] $FILENAME is executable"
else
	echo "[-] Downloaded file is not executable. Exiting."
	exit 1
fi

# Create install directory
echo "[*] Creating installation directory at ${INSTALL_DIR}..."
sudo mkdir -p "$INSTALL_DIR"

# Generate server config
echo "[*] Generating server configuration..."
sudo ./"$FILENAME" config generate \
	--server \
	--non-interactive \
	--config "${INSTALL_DIR}/server.config.yaml" \
	--port 8889 \
	--admin-user "$ADMIN_USER" \
	--admin-password "$ADMIN_PASSWORD" \
	--data-dir "${INSTALL_DIR}/data"
echo "[+] Velociraptor server configuration generated successfully."

# Generate client config
echo "[*] Generating client configuration..."
sudo ./"$FILENAME" config generate \
	--client \
	--non-interactive \
	--config "${INSTALL_DIR}/client.config.yaml" \
	--server "${INSTALL_DIR}/server.config.yaml" \
	--data-dir "${INSTALL_DIR}/data/client"
echo "[+] Velociraptor client configuration generated successfully."

# Update server GUI bind_address
CURRENT_IP=$(hostname -I | awk '{print $1}')
echo "[*] Updating server GUI bind_address to ${CURRENT_IP}..."
sudo sed -i "s/bind_address: 127\.0\.0\.1/bind_address: ${CURRENT_IP}/" "${INSTALL_DIR}/server.config.yaml"
echo "[+] Server GUI will bind to ${CURRENT_IP}"

# Generate Debian server package
echo "[*] Generating Debian server package..."
sudo ./"$FILENAME" --config "${INSTALL_DIR}/server.config.yaml" debian server --binary "$FILENAME"

# Find and install the Debian package
DEB_FILE=$(find . -maxdepth 1 -type f -name "velociraptor_*.deb" | head -n 1)
if [[ -f "$DEB_FILE" ]]; then
	echo "[*] Installing Debian package: $DEB_FILE"
	sudo dpkg -i "$DEB_FILE"
	echo "[+] Velociraptor Debian package installed."
else
	echo "[-] Could not find the generated .deb package."
	exit 1
fi
