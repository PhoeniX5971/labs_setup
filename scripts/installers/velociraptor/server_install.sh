#!/bin/bash
set -euo pipefail

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
