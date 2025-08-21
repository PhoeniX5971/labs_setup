#!/bin/bash

# --- Parameters ---
while getopts "p:i:" opt; do
	case $opt in
	p) ELASTIC_PASSWORD="$OPTARG" ;;
	i) IPADDR="$OPTARG" ;;
	*) echo "Usage: -i <ip> -p <password>" ;;
	esac
done

if [[ -z "$ELASTIC_PASSWORD" || -z "$IPADDR" ]]; then
	echo "Usage: $0 -i <kibana_ip> -p <elastic_password>"
	exit 1
fi

KIBANA_URL="http://$IPADDR:5601"
POLICY_ID="fleet-server-policy"

echo "Using Kibana URL: $KIBANA_URL"

# --- Create Fleet Enrollment Token ---
ENROLLMENT_TOKEN=$(curl -s -u "elastic:$ELASTIC_PASSWORD" \
	-H "kbn-xsrf: true" \
	-H "Content-Type: application/json" \
	-X POST "$KIBANA_URL/api/fleet/enrollment_api_keys" \
	-d "{\"policy_id\":\"$POLICY_ID\"}" | jq -r '.item.api_key')

echo "Enrollment token created: $ENROLLMENT_TOKEN"

# --- Download Elastic Agent if not exists ---
AGENT_TAR="/tmp/elastic-agent.tar.gz"
AGENT_DIR="/opt/elastic-agent"

if [[ ! -f "$AGENT_TAR" ]]; then
	echo "Downloading Elastic Agent..."
	curl -L -o "$AGENT_TAR" "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-9.1.2-linux-x86_64.tar.gz"
else
	echo "Elastic Agent tar already exists. Skipping download."
fi

# --- Extract and install ---
mkdir -p "$AGENT_DIR"
tar -xzf "$AGENT_TAR" -C "$AGENT_DIR" --strip-components=1

sudo "$AGENT_DIR/elastic-agent" install \
	--url "http://$IPADDR:8220" \
	--enrollment-token "$ENROLLMENT_TOKEN" \
	--insecure \
	-f
