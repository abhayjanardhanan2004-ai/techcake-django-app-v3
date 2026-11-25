#!/bin/bash
set -e

echo "Validating deployed Django application..."

EXPECTED_SHA="${EXPECTED_SHA:-}"

for i in $(seq 1 30); do
    RESPONSE=$(curl -sS --fail http://127.0.0.1:8000/health || true)

    if [ -n "$RESPONSE" ]; then
        echo "Health endpoint response: $RESPONSE"

        if [ -n "$EXPECTED_SHA" ] && echo "$RESPONSE" | grep -q "$EXPECTED_SHA"; then
            echo "Health check passed. Deployed SHA verified: $EXPECTED_SHA"
            exit 0
        fi

        if [ -z "$EXPECTED_SHA" ]; then
            echo "Health endpoint responding. No expected SHA provided."
            exit 0
        fi
    fi

    echo "Waiting for application health... ($i/30)"
    sleep 5
done

echo "Validation failed: application health or SHA verification failed."
exit 1
