pipeline {
    agent any

    environment {
        AWS_REGION = "ap-south-1"
        INSTANCE_ID = "i-026b3fdb2246e82a3"
    }

    stages {
        stage("Checkout") {
            steps {
                checkout scm
            }
        }

        stage("Deploy via SSM") {
            steps {
                sh '''
                set -e

                echo "Triggering deployment via SSM..."

                COMMAND_ID=$(aws ssm send-command \
                  --instance-ids ${INSTANCE_ID} \
                  --document-name AWS-RunShellScript \
                  --parameters commands="/home/ubuntu/deploy.sh" \
                  --region ${AWS_REGION} \
                  --query "Command.CommandId" \
                  --output text)

                echo "SSM Command ID: $COMMAND_ID"

                echo "Waiting for SSM command to finish..."

                STATUS="InProgress"

                while [ "$STATUS" = "Pending" ] || [ "$STATUS" = "InProgress" ]; do
                    sleep 5
                    STATUS=$(aws ssm get-command-invocation \
                      --command-id $COMMAND_ID \
                      --instance-id ${INSTANCE_ID} \
                      --region ${AWS_REGION} \
                      --query "Status" \
                      --output text)

                    echo "Current status: $STATUS"
                done

                echo "Final SSM Status: $STATUS"

                if [ "$STATUS" != "Success" ]; then
                    echo "❌ DEPLOYMENT FAILED ON WORKER NODE"
                    echo "Fetching logs..."

                    aws ssm get-command-invocation \
                      --command-id $COMMAND_ID \
                      --instance-id ${INSTANCE_ID} \
                      --region ${AWS_REGION}

                    exit 1
                fi

                echo "✅ DEPLOYMENT SUCCEEDED"
                '''
            }
        }
    }

    post {
        success {
            echo "🎉 Pipeline completed successfully"
        }
        failure {
            echo "🔥 Pipeline failed because deployment failed"
        }
    }
}

