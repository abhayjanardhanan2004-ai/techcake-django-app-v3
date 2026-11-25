#!/bin/bash
set -e

APP_DIR="/opt/techcake-app"
METADATA="$APP_DIR/deploy/image.env"

if [ ! -f "$METADATA" ]; then
    echo "ERROR: Deployment image metadata not found: $METADATA"
    exit 1
fi

source "$METADATA"

if [ -z "$IMAGE_URI" ] || [ "$IMAGE_URI" = "PLACEHOLDER" ]; then
    echo "ERROR: IMAGE_URI is missing or still a placeholder."
    exit 1
fi

echo "Deploying image: $IMAGE_URI"

docker pull "$IMAGE_URI"

docker rm -f techcake-app 2>/dev/null || true

docker run -d \
    --name techcake-app \
    --restart always \
    -p 8000:8000 \
    "$IMAGE_URI"

echo "Container started successfully."
