#!/bin/bash
set -euo pipefail

# Defaults
INSTALL_DIR="/opt/velociraptor"
ADMIN_USER="admin"
ADMIN_PASSWORD="password123"
FORCE=false

show_help() {
	cat <<EOF
Usage: $0 [--help] [--force] [-dir <install_dir>] [-username <admin_user>] [-password <admin_password>]

Options:
  --help              Show this help
  --force             Force re-download of binary
  -dir / --dir        Install dir (default: /opt/velociraptor)
  -username / --username  Admin username (default: admin)
  -password / --password  Admin password (default: password123)
EOF
}

# parse args
while [[ $# -gt 0 ]]; do
	case "$1" in
	--help)
		show_help
		exit 0
		;;
	--force)
		FORCE=true
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
		echo "Unknown arg: $1"
		show_help
		exit 1
		;;
	esac
done

# check dependencies
if ! command -v curl >/dev/null 2>&1; then
	echo "curl required"
	exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
	echo "jq is required to parse GitHub JSON. Install 'jq' (apt install jq) and re-run."
	exit 1
fi

echo "[*] Fetching latest Velociraptor release info..."
RELEASE_JSON=$(curl -s "https://api.github.com/repos/Velocidex/velociraptor/releases/latest")

# pick linux-amd64 asset (exact asset name ends with linux-amd64)
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r '.assets[] | select(.name | test("linux-amd64$")) | .browser_download_url' | head -n1)
if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
	echo "[-] Could not find linux-amd64 asset in latest release."
	exit 1
fi

FILENAME=$(basename "$DOWNLOAD_URL")
BINARY_PATH="$(pwd)/${FILENAME}"
echo "[+] Latest asset: $FILENAME"
echo "[+] Download URL: $DOWNLOAD_URL"

# Download binary (skip if exists and executable unless --force)
if [[ -x "$BINARY_PATH" && "$FORCE" = false ]]; then
	echo "[*] Binary already exists and is executable: $BINARY_PATH (skipping download)"
else
	echo "[*] Downloading $FILENAME..."
	curl -L -o "$BINARY_PATH" "$DOWNLOAD_URL"
	chmod +x "$BINARY_PATH"
	if [[ ! -x "$BINARY_PATH" ]]; then
		echo "[-] Downloaded file is not executable. Exiting."
		exit 1
	fi
	echo "[+] Download complete and executable: $BINARY_PATH"
fi

# ensure install dir exists
echo "[*] Creating install dir: $INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"

# Generate server config (write stdout to file) — valid command per `--help`
echo "[*] Generating server config -> ${INSTALL_DIR}/server.config.yaml"
sudo bash -c "umask 022; \"$BINARY_PATH\" config generate > \"${INSTALL_DIR}/server.config.yaml\""
if [[ ! -s "${INSTALL_DIR}/server.config.yaml" ]]; then
	echo "[-] server.config.yaml appears empty. Aborting."
	exit 1
fi

# Generate client config using server config (documented pattern: -c <server> config client > client.config)
echo "[*] Generating client config -> ${INSTALL_DIR}/client.config.yaml"
sudo bash -c "\"$BINARY_PATH\" --config \"${INSTALL_DIR}/server.config.yaml\" config client > \"${INSTALL_DIR}/client.config.yaml\""
if [[ ! -s "${INSTALL_DIR}/client.config.yaml" ]]; then
	echo "[-] client.config.yaml appears empty. Aborting."
	exit 1
fi

# Set GUI bind address and port in server config
# Get primary IP (works on Ubuntu)
CURRENT_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
if [[ -z "$CURRENT_IP" ]]; then
	# fallback via ip route
	CURRENT_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')
fi
if [[ -z "$CURRENT_IP" ]]; then
	echo "[-] Could not determine server IP. Please edit ${INSTALL_DIR}/server.config.yaml manually."
else
	echo "[*] Will set GUI bind_address -> $CURRENT_IP and GUI bind_port -> 8889"

	if command -v yq >/dev/null 2>&1; then
		# yq v4 syntax
		echo "[*] Using yq to edit YAML"
		sudo yq eval -i ".API.GUI.bind_address = \"${CURRENT_IP}\" | .API.GUI.bind_port = 8889" "${INSTALL_DIR}/server.config.yaml"
	else
		# fallback sed: replace common occurrences. This targets lines with 'bind_address: 127.0.0.1' and 'bind_port: <num>'
		sudo sed -i "s/bind_address: 127\.0\.0\.1/bind_address: ${CURRENT_IP}/g" "${INSTALL_DIR}/server.config.yaml"
		# replace bind_port lines under GUI or API; safest is to replace common default 8889 or any numeric bind_port with 8889
		sudo sed -i "s/bind_port: [0-9]\+/bind_port: 8889/g" "${INSTALL_DIR}/server.config.yaml"
	fi
fi

# Create admin GUI user via documented command: user add --role=ROLE <username> [<password>]
echo "[*] Creating admin user '${ADMIN_USER}' (role=administrator)"
# the binary accepts top-level --config flag; use it per --help
sudo "$BINARY_PATH" --config "${INSTALL_DIR}/server.config.yaml" user add --role=administrator "${ADMIN_USER}" "${ADMIN_PASSWORD}" || {
	echo "[-] 'user add' failed. If an admin already exists, this may be expected. Check /opt/velociraptor/users."
}

# Generate Debian package
echo "[*] Generating Debian server package (debian server)..."
sudo "$BINARY_PATH" debian server --config "${INSTALL_DIR}/server.config.yaml" --binary "${BINARY_PATH}"

# find generated .deb safely
DEB_FILE=$(find . -maxdepth 1 -type f -name "velociraptor_*.deb" -print -quit || true)
if [[ -z "$DEB_FILE" ]]; then
	echo "[-] Could not find generated .deb in current dir."
	echo "    Check output of 'velociraptor debian server' for where it wrote the package."
	exit 1
fi

echo "[*] Installing Debian package: $DEB_FILE"
sudo dpkg -i "$DEB_FILE"

echo "[+] Done. Next steps:"
echo "  - Start the server: sudo ${BINARY_PATH} --config ${INSTALL_DIR}/server.config.yaml frontend -v"
echo "  - Or create a systemd unit pointing to that ExecStart."
echo "  - GUI will be available on https://${CURRENT_IP}:8889 (self-signed cert by default)."
