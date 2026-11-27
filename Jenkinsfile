
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 45, unit: 'MINUTES')
    }

    environment {
        AWS_REGION = 'ap-south-1'
        ECR_REGISTRY = '451782721864.dkr.ecr.ap-south-1.amazonaws.com'
        ECR_REPOSITORY = 'techcake-django-app-v3'
        HEALTH_URL = 'https://djangov2.tc-2026-0051.nixlabs.in/health'
        APP_INSTANCE_ID = 'i-0a02822ba092a1f34'
        IMAGE_URI = '451782721864.dkr.ecr.ap-south-1.amazonaws.com/techcake-django-app-v3'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                script {
                    env.GIT_SHA = sh(
                        script: 'git rev-parse HEAD',
                        returnStdout: true
                    ).trim()

                    echo "Building commit: ${env.GIT_SHA}"
                }
            }
        }

        stage('Test') {
            steps {
                sh '''
                    set -eu

                    python3.11 -m venv .venv
                    .venv/bin/python -m pip install --upgrade pip
                    .venv/bin/pip install -r requirements.txt

                    DB_ENGINE=sqlite .venv/bin/python manage.py test
                '''
            }
        }

        stage('Build') {
            steps {
                sh '''
                    set -eu

                    docker build \
                      --build-arg APP_VERSION="$GIT_SHA" \
                      -t "$IMAGE_URI:$GIT_SHA" .
                '''
            }
        }

        stage('Scan') {
            steps {
                sh '''
                    set -eu

                    echo "Scanning $IMAGE_URI:$GIT_SHA"

                    trivy image \
                      --scanners vuln \
                      --severity HIGH,CRITICAL \
                      --format json \
                      --output trivy-report.json \
                      "$IMAGE_URI:$GIT_SHA"

                    python3.11 - <<'PY'
import json
import sys

with open("trivy-report.json", encoding="utf-8") as report:
    data = json.load(report)

high = 0
critical = 0

for result in data.get("Results") or []:
    for vuln in result.get("Vulnerabilities") or []:
        severity = vuln.get("Severity", "").upper()
        if severity == "HIGH":
            high += 1
        elif severity == "CRITICAL":
            critical += 1

print(f"HIGH vulnerabilities: {high}")
print(f"CRITICAL vulnerabilities: {critical}")

if critical:
    print("BLOCKED: Critical vulnerabilities found.")
    sys.exit(1)

print("PASS: No Critical vulnerabilities found.")
PY
                '''
            }
        }

        stage('Push') {
            steps {
                sh '''
                    set -eu
                    set +x

                    /usr/local/bin/aws ecr get-login-password \
                      --region "$AWS_REGION" \
                      | docker login \
                          --username AWS \
                          --password-stdin "$ECR_REGISTRY"

                    docker push "$IMAGE_URI:$GIT_SHA"

                    docker logout "$ECR_REGISTRY" || true
                '''
            }
        }

     stage('Deploy') {
    steps {
        sh '''
            set -eu

            echo "Preparing CodeDeploy revision for: $GIT_SHA"

            cat > deploy/image.env <<EOF
IMAGE_URI=$IMAGE_URI:$GIT_SHA
EXPECTED_SHA=$GIT_SHA
EOF

            rm -f codedeploy-revision.zip

            zip -r codedeploy-revision.zip appspec.yml deploy/

            S3_KEY="revisions/${GIT_SHA}.zip"

            /usr/local/bin/aws s3 cp codedeploy-revision.zip \
              "s3://techcake-codedeploy-artifacts-451782721864-ap-south-1/$S3_KEY" \
              --region "$AWS_REGION"

          DEPLOYMENT_ID=$(/usr/local/bin/aws deploy create-deployment \
              --application-name techcake-django-app-v3 \
              --deployment-group-name techcake-production-blue-green \
              --deployment-config-name CodeDeployDefault.AllAtOnce \
              --s3-location bucket=techcake-codedeploy-artifacts-451782721864-ap-south-1,key="$S3_KEY",bundleType=zip \
              --description "Jenkins Blue-Green deployment $GIT_SHA" \
              --region "$AWS_REGION" \
              --query 'deploymentId' \
              --output text)

            echo "Deployment ID: $DEPLOYMENT_ID"

            for attempt in $(seq 1 180); do
               STATUS=$(/usr/local/bin/aws deploy get-deployment \
                  --deployment-id "$DEPLOYMENT_ID" \
                  --region "$AWS_REGION" \
                  --query 'deploymentInfo.status' \
                  --output text)

                echo "CodeDeploy status: $STATUS"

                case "$STATUS" in
                    Succeeded)
                        echo "Blue-Green deployment succeeded!"
                        exit 0
                        ;;
                    Failed|Stopped)
                        echo "Deployment ended with status: $STATUS"
                        exit 1
                        ;;
                esac

                sleep 10
            done

            echo "Timed out waiting for CodeDeploy."
            exit 1
        '''
    }
}

        stage('Verify') {
            steps {
                sh '''
                    set -eu

                    curl -k -sS --fail --max-time 30 \
                      "$HEALTH_URL" \
                      -o health.json

                    python3.11 - <<'PY'
import json
import os
import sys

with open("health.json", encoding="utf-8") as response:
    data = json.load(response)

expected = os.environ["GIT_SHA"]

print(json.dumps(data, indent=2))

if data.get("status") != "ok":
    print("FAIL: Application health status is not OK.")
    sys.exit(1)

if data.get("version") != expected:
    print("FAIL: Deployed version does not match Git commit.")
    sys.exit(1)

print("PASS: Application is healthy and deployed SHA matches.")
PY
                '''
            }
        }
    }

    post {
        always {
            script {
                if (!fileExists('trivy-report.json')) {
                    writeFile(
                        file: 'trivy-report.json',
                        text: '{"status":"scan_not_completed"}'
                    )
                }
            }

            archiveArtifacts(
                artifacts: 'trivy-report.json',
                allowEmptyArchive: true
            )
        }

        success {
            echo 'CI/CD pipeline completed successfully!'
        }

        failure {
            echo 'Pipeline failed. Push and deployment stages are skipped when earlier stages fail.'
        }
    }
}



          

 


