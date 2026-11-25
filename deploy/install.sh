#!/bin/bash
set -e

echo "Preparing CodeDeploy deployment environment..."

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed."
    exit 1
fi

systemctl enable docker
systemctl start docker

AWS_REGION="ap-south-1"
ECR_REGISTRY="451782721864.dkr.ecr.ap-south-1.amazonaws.com"

if ! command -v aws >/dev/null 2>&1; then
    echo "ERROR: AWS CLI is not installed."
    exit 1
fi

echo "Authenticating with Amazon ECR..."

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login \
      --username AWS \
      --password-stdin "$ECR_REGISTRY"

echo "Install hook completed successfully."
