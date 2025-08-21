#!/bin/bash

set -e

# Default values
ELASTIC_USER="elastic"
ELASTIC_HOST="localhost"
ELASTIC_PORT="9200"
NEW_PASSWORD=""

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	--password)
		NEW_PASSWORD="$2"
		shift 2
		;;
	*)
		echo "[!] Unknown argument: $1"
		echo "Usage: $0 [--password <new_password>]"
		exit 1
		;;
	esac
done

if [[ -z "$NEW_PASSWORD" ]]; then
	echo "[!] No password provided. Use --password <new_password>"
	exit 1
fi

echo "[*] Updating system packages..."
sudo apt update -y
sudo apt upgrade -y

echo "[*] Installing prerequisites..."
sudo apt install -y \
	ca-certificates \
	curl \
	gnupg \
	lsb-release \
	jq

echo "[*] Adding Docker’s official GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
	sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "[*] Setting up the Docker repository..."
echo \
	"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" |
	sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

echo "[*] Installing Docker Engine and Compose..."
sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[*] Enabling Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

echo "[*] Adding current user to the docker group..."
sudo usermod -aG docker $USER

echo "[*] Docker and Docker Compose installed successfully!"
echo "[*] Please log out and log back in or run: newgrp docker"

# --- ELK Stack Setup ---

echo "[*] Cloning docker-elk repo..."
git clone https://github.com/deviantony/docker-elk.git
cd docker-elk

echo "[*] Injecting Kibana encryption keys into kibana.yml..."
cat <<EOF >>kibana/config/kibana.yml
xpack.encryptedSavedObjects.encryptionKey: 428439d8f6d9403b47efc5583d76499f
xpack.reporting.encryptionKey: bd2f3be59b56f6cacb57b4746e481cdb
xpack.security.encryptionKey: a26f6d6e4138ceca9b9edf9cfca24cb8
EOF

echo "[*] Initializing built-in Elasticsearch users..."
docker compose up setup

echo "[*] Starting ELK stack..."
docker compose up -d

sleep 20

# Reset elastic password
ES_CONTAINER_ID=$(docker ps -aqf "name=docker-elk-elasticsearch")

if [ -n "$ES_CONTAINER_ID" ]; then
	echo "[*] Elasticsearch container ID: $ES_CONTAINER_ID"
	echo "[*] Resetting password for 'elastic' user..."
	ELASTIC_PASSWORD=$(docker exec -i "$ES_CONTAINER_ID" bin/elasticsearch-reset-password --batch --user elastic | grep 'New value:' | awk '{print $3}' | tr -d '\r')
	echo "[+] Elastic password: $ELASTIC_PASSWORD"
else
	echo "[!] Failed to find Elasticsearch container."
	exit 1
fi

# Define Elasticsearch and Kibana hosts
ES_HOST="http://localhost:9200"
KIBANA_HOST="http://localhost:5601"

# Generate Fleet Server token
echo "[*] Generating Fleet Server service token..."
RESPONSE=$(curl -s -u elastic:$ELASTIC_PASSWORD \
	--request POST "$ES_HOST/_security/service/elastic/fleet-server/credential/token" \
	-H 'Content-Type: application/json')

FLEET_TOKEN=$(echo "$RESPONSE" | jq -r '.token.value')

if [[ "$FLEET_TOKEN" == "null" || -z "$FLEET_TOKEN" ]]; then
	echo "[!] Failed to generate Fleet Server token."
	echo "Response: $RESPONSE"
	exit 1
fi

echo "[+] Fleet Server Token: $FLEET_TOKEN"

# Define policy name and namespace
POLICY_NAME="Fleet Server Policy"
POLICY_NAMESPACE="default"

echo "[*] Creating Fleet Server policy if not already exists..."

CREATE_POLICY_RESPONSE=$(curl -s -u elastic:$ELASTIC_PASSWORD \
	-X POST "$KIBANA_HOST/api/fleet/agent_policies" \
	-H 'kbn-xsrf: true' \
	-H 'Content-Type: application/json' \
	-d "{
    \"name\": \"$POLICY_NAME\",
    \"namespace\": \"$POLICY_NAMESPACE\",
    \"is_default_fleet_server\": true
  }")

# Check if it was a conflict or success
if echo "$CREATE_POLICY_RESPONSE" | grep -q '"statusCode":409'; then
	echo "[!] Policy already exists. Fetching existing policy ID..."
	POLICY_ID=$(curl -s -u elastic:$ELASTIC_PASSWORD \
		-X GET "$KIBANA_HOST/api/fleet/agent_policies" \
		-H 'kbn-xsrf: true' | jq -r --arg name "$POLICY_NAME" '.items[] | select(.name == $name) | .id')
else
	POLICY_ID=$(echo "$CREATE_POLICY_RESPONSE" | jq -r '.item.id')
fi

if [[ -z "$POLICY_ID" ]]; then
	echo "[!] Failed to retrieve Fleet Server Policy ID."
	echo "Response: $CREATE_POLICY_RESPONSE"
	exit 1
fi

echo "[+] Fleet Server Policy ID: $POLICY_ID"

# Download and install Elastic Agent as Fleet Server
cd ..
curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.13.0-linux-x86_64.tar.gz
tar xzvf elastic-agent-8.13.0-linux-x86_64.tar.gz
cd elastic-agent-8.13.0-linux-x86_64

echo "[*] Installing Elastic Agent as Fleet Server..."

sudo ./elastic-agent install \
	--non-interactive \
	--url=$ES_HOST \
	--fleet-server-es=$ES_HOST \
	--fleet-server-service-token=$FLEET_TOKEN \
	--fleet-server-policy=$POLICY_ID \
	--fleet-server-insecure-http

echo "[✔] Fleet Server enrolled and agent installed successfully!"

sudo docker compose -f docker-compose.yml -f extensions/fleet/fleet-compose.yml up -d

echo "[*] Resetting 'elastic' password via REST API..."

curl -s -u "$ELASTIC_USER:$ELASTIC_PASSWORD" \
	-H "Content-Type: application/json" \
	-X POST "http://$ELASTIC_HOST:$ELASTIC_PORT/_security/user/$ELASTIC_USER/_password" \
	-d "{\"password\":\"$NEW_PASSWORD\"}"

if [[ $? -eq 0 ]]; then
	echo "[+] Password for '$ELASTIC_USER' reset successfully to: $NEW_PASSWORD"
else
	echo "[!] Failed to reset password"
	exit 1
fi
