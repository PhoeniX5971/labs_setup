#!/bin/bash
set -euo pipefail

# Default values
INSTALL_DIR="/opt/velociraptor"
ADMIN_USER="admin"
ADMIN_PASSWORD="password123"
FORCE_DOWNLOAD=false

# Show usage/help
show_help() {
	echo "Usage: $0 [--help] [-dir <install_dir>] [-username <admin_user>] [-password <admin_password>] [--force]"
	echo
	echo "Options:"
	echo "  --help          Show this help message"
	echo "  -dir            Installation directory (default: /opt/velociraptor)"
	echo "  -username       Admin username (default: admin)"
	echo "  -password       Admin password (default: password123)"
	echo "  --force         Force re-download of Velociraptor binary"
}

# Parse named arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	--help)
		show_help
		exit 0
		;;
	--force)
		FORCE_DOWNLOAD=true
		shift
		;;
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
		show_help
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

# Download the binary if missing or forced
if [[ -x "$FILENAME" && "$FORCE_DOWNLOAD" = false ]]; then
	echo "[*] Velociraptor binary already exists and is executable. Skipping download."
else
	echo "[*] Downloading Velociraptor..."
	curl -L -o "$FILENAME" "$DOWNLOAD_URL"
	chmod +x "$FILENAME"
	if [[ ! -x "$FILENAME" ]]; then
		echo "[-] Downloaded file is not executable. Exiting."
		exit 1
	fi
	echo "[+] $FILENAME is now executable"
fi

# Create installation directory
echo "[*] Creating installation directory at ${INSTALL_DIR}..."
sudo mkdir -p "$INSTALL_DIR"

# Generate server config
echo "[*] Generating server configuration..."
sudo ./"$FILENAME" config generate \
	--non-interactive \
	--server \
	--config "${INSTALL_DIR}/server.config.yaml" \
	--port 8889 \
	--admin-user "$ADMIN_USER" \
	--admin-password "$ADMIN_PASSWORD" \
	--data-dir "${INSTALL_DIR}/data"
echo "[+] Velociraptor server configuration generated successfully."

# Generate client config
echo "[*] Generating client configuration..."
sudo ./"$FILENAME" config generate \
	--non-interactive \
	--client \
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
sudo ./"$FILENAME" debian server \
	--config "${INSTALL_DIR}/server.config.yaml" \
	--binary "$FILENAME"

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
