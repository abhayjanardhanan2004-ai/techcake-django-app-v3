
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

            echo "Deploying commit: $GIT_SHA"

            python3.11 - <<'PY'
import json
import os

command = (
    "sudo /opt/django1/techcake-django-app-v2/deploy.sh "
    + os.environ["GIT_SHA"]
)

with open("ssm-parameters.json", "w") as f:
    json.dump({"commands": [command]}, f)
PY

            COMMAND_ID=$(/usr/local/bin/aws ssm send-command \
              --region "$AWS_REGION" \
              --instance-ids "$APP_INSTANCE_ID" \
              --document-name AWS-RunShellScript \
              --parameters file://ssm-parameters.json \
              --query 'Command.CommandId' \
              --output text)

            echo "SSM Command ID: $COMMAND_ID"

            STATUS="Pending"

            for attempt in $(seq 1 60); do
                STATUS=$(/usr/local/bin/aws ssm get-command-invocation \
                  --region "$AWS_REGION" \
                  --command-id "$COMMAND_ID" \
                  --instance-id "$APP_INSTANCE_ID" \
                  --query 'Status' \
                  --output text 2>/dev/null || true)

                echo "Deployment status: $STATUS"

                case "$STATUS" in
                    Success|Failed|TimedOut|Cancelled|Cancelling|Undeliverable|Terminated)
                        break
                        ;;
                esac

                sleep 5
            done

            /usr/local/bin/aws ssm get-command-invocation \
              --region "$AWS_REGION" \
              --command-id "$COMMAND_ID" \
              --instance-id "$APP_INSTANCE_ID" \
              --query '{Status:Status,Output:StandardOutputContent,Error:StandardErrorContent}' \
              --output json

            if [ "$STATUS" != "Success" ]; then
                echo "Deployment failed."
                exit 1
            fi
        '''
    }
}

      

        stage('Verify') {
            steps {
                sh '''
                    set -eu

                    curl -fsS "$HEALTH_URL" -o health.json

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

