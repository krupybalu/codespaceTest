#!/usr/bin/env bash
# BC Codespaces launcher bootstrap (prototype - Option 2)
# Reads $BC_LAUNCH_DATA, parses the BC payload, clones the customer repo,
# and renders launch.json. In production this would also handle JWT signature
# verification, host-aware auth (gh / glab / az), and the v2 sourceBlobUrl branch.

set -euo pipefail

if [[ -z "${BC_LAUNCH_DATA:-}" ]]; then
    cat > /workspaces/.bc-error <<EOF
BC_LAUNCH_DATA env var is not set.

This codespace was opened directly, not via the BC prototype launcher.
Open the prototype page (prototype/index.html), set the secret, then
reopen the codespace.
EOF
    echo "BC_LAUNCH_DATA not set - skipping BC bootstrap."
    exit 0
fi

echo "================================="
echo "BC Codespace Bootstrap (Prototype)"
echo "================================="

# In production, BC_LAUNCH_DATA is a signed JWT and we'd verify the signature.
# Prototype: plain JSON.
PAYLOAD="$BC_LAUNCH_DATA"
if ! echo "$PAYLOAD" | jq . > /workspaces/.bc-context.json 2>/dev/null; then
    echo "Failed to parse BC_LAUNCH_DATA as JSON."
    echo "$PAYLOAD" > /workspaces/.bc-error
    exit 1
fi

REPO_URL=$(jq -r '.repositoryUrl    // empty' /workspaces/.bc-context.json)
COMMIT=$(  jq -r '.commit           // empty' /workspaces/.bc-context.json)
TENANT_ID=$(jq -r '.tenantId        // empty' /workspaces/.bc-context.json)
ENV_NAME=$( jq -r '.environmentName // empty' /workspaces/.bc-context.json)
EXT_ID=$(   jq -r '.extensionId     // empty' /workspaces/.bc-context.json)
EXT_VER=$(  jq -r '.extensionVersion // empty' /workspaces/.bc-context.json)

echo "Extension: $EXT_ID $EXT_VER"
echo "Repo:      $REPO_URL"
echo "Commit:    ${COMMIT:-<latest>}"
echo "Tenant:    $TENANT_ID"
echo "Sandbox:   $ENV_NAME"
echo "================================="

# Clone customer source. Prototype uses anonymous/HTTPS clone; production would
# dispatch on the host (gh / glab / az / GCM) for private repos.
if [[ -n "$REPO_URL" ]]; then
    if [[ -d /workspaces/extension ]]; then
        echo "/workspaces/extension already exists - skipping clone."
    else
        echo "Cloning $REPO_URL into /workspaces/extension..."
        if ! git clone "$REPO_URL" /workspaces/extension 2>&1; then
            echo "Clone failed. For the prototype, ensure the repo is public."
            exit 1
        fi
    fi

    if [[ -n "$COMMIT" && "$COMMIT" != "null" ]]; then
        if ! git -C /workspaces/extension checkout "$COMMIT" 2>/dev/null; then
            echo "Note: commit $COMMIT not found - using default branch."
            echo "Commit $COMMIT unavailable; on default branch instead." \
                > /workspaces/extension/.bc-banner
        fi
    fi
fi

# Render launch.json so AL: Publish targets the right BC sandbox
mkdir -p /workspaces/extension/.vscode
TARGET=/workspaces/extension/.vscode/launch.json
[[ -f "$TARGET" ]] && TARGET=/workspaces/extension/.vscode/launch.bc.json

cat > "$TARGET" <<EOF
{
    "version": "0.2.0",
    "configurations": [{
        "type": "al",
        "request": "launch",
        "name": "Publish to BC sandbox",
        "environmentType": "Sandbox",
        "environmentName": "$ENV_NAME",
        "tenant": "$TENANT_ID",
        "schemaUpdateMode": "Synchronize",
        "breakOnError": "All",
        "launchBrowser": true
    }]
}
EOF
echo "Wrote $TARGET"

# Best-effort: invalidate the secret so a restart doesn't reuse stale context.
# Whether $GITHUB_TOKEN has the scope to DELETE user secrets is one of the
# open prototype questions in research.md.
if curl -fsSL -X DELETE \
       -H "Authorization: bearer $GITHUB_TOKEN" \
       -H "Accept: application/vnd.github+json" \
       https://api.github.com/user/codespaces/secrets/BC_LAUNCH_DATA \
       > /dev/null 2>&1; then
    echo "Cleaned up BC_LAUNCH_DATA secret."
else
    echo "Note: couldn't auto-clean BC_LAUNCH_DATA (will be overwritten on next launch)."
fi

echo
echo "Bootstrap complete."
echo "Inspect /workspaces/.bc-context.json to see the launch payload."
