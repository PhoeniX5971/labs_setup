#!/bin/bash

# Replace with your values
KIBANA_URL="http://localhost:5601"
ELASTIC_USER="elastic"
ELASTIC_PASSWORD="qSFlTn-Ev+p3h0-4kg-p"

# Fetch agent policies
curl -s -u $ELASTIC_USER:$ELASTIC_PASSWORD \
	-H "kbn-xsrf: true" \
	"$KIBANA_URL/api/fleet/agent_policies" | jq '.items[] | {id, name}'
