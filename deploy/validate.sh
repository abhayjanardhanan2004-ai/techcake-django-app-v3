 #!/bin/bash
set -e

APP_DIR="/opt/techcake-app"
METADATA="$APP_DIR/deploy/image.env"

if [ ! -f "$METADATA" ]; then
    echo "ERROR: image.env not found"
    exit 1
fi

source "$METADATA"

if [ -z "$EXPECTED_SHA" ] || [ "$EXPECTED_SHA" = "PLACEHOLDER" ]; then
    echo "ERROR: EXPECTED_SHA is missing or invalid"
    exit 1
fi

echo "Expected deployed SHA: $EXPECTED_SHA"

for i in $(seq 1 30); do
    RESPONSE=$(curl -sS --fail http://127.0.0.1:8000/health || true)

    if [ -n "$RESPONSE" ]; then
        ACTUAL_SHA=$(echo "$RESPONSE" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("version", ""))
except Exception:
    print("")
' 2>/dev/null || true)

        if [ "$ACTUAL_SHA" = "$EXPECTED_SHA" ]; then
            echo "Validation successful!"
            echo "Health response: $RESPONSE"
            echo "Verified SHA: $ACTUAL_SHA"
            exit 0
        fi
    fi

    echo "Waiting for health check and SHA verification ($i/30)..."
    sleep 5
done

echo "ERROR: Health check failed or deployed SHA does not match."
exit 1
