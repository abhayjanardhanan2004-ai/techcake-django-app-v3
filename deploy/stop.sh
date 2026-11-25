#!/bin/bash
set -e

echo "Stopping existing TechCake application..."

docker stop techcake-app || true
docker rm techcake-app || true

echo "Application container stopped and removed."
