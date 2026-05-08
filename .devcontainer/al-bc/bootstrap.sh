#!/usr/bin/env bash
# Minimal BC Codespaces bootstrap.
# Reads $BC_LAUNCH_DATA, extracts environmentName, writes .vscode/launch.json.

set -euo pipefail

if [[ -z "${BC_LAUNCH_DATA:-}" ]]; then
    echo "BC_LAUNCH_DATA env var is not set."
    echo "This codespace was opened directly, not via the BC prototype launcher."
    exit 0
fi

ENV_NAME=$(echo "$BC_LAUNCH_DATA" | jq -r '.environmentName // empty')

if [[ -z "$ENV_NAME" ]]; then
    echo "BC_LAUNCH_DATA does not contain environmentName."
    echo "Payload: $BC_LAUNCH_DATA"
    exit 1
fi

echo "Bootstrap: received environmentName = $ENV_NAME"

mkdir -p .vscode
cat > .vscode/launch.json <<EOF
{
    "version": "0.2.0",
    "configurations": [{
        "type": "al",
        "request": "launch",
        "name": "Publish to BC sandbox",
        "environmentType": "Sandbox",
        "environmentName": "$ENV_NAME",
        "schemaUpdateMode": "Synchronize",
        "breakOnError": "All",
        "launchBrowser": true
    }]
}
EOF

echo "Wrote .vscode/launch.json with environmentName=$ENV_NAME"
