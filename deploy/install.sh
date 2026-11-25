#!/bin/bash
set -e

echo "Installing deployment dependencies..."

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed"
    exit 1
fi

systemctl enable docker
systemctl start docker

echo "Install hook completed."
