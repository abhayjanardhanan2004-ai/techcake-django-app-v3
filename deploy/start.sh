#!/bin/bash
set -e

IMAGE_URI="$1"

if [ -z "$IMAGE_URI" ]; then
    echo "Usage: start.sh <image-uri>"
    exit 1
fi

echo "Starting application container: $IMAGE_URI"

docker pull "$IMAGE_URI"

docker rm -f techcake-app || true

docker run -d \
  --name techcake-app \
  --restart always \
  -p 8000:8000 \
  "$IMAGE_URI"

echo "Container started."
