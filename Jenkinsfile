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

        stage("Detect Changes") {
            steps {
                script {
                    CHANGED = sh(
                        script: "git diff --name-only HEAD~1 HEAD",
                        returnStdout: true
                    ).trim()

                    echo "Changed files:\n${CHANGED}"

                    DEPLOY_NASA = CHANGED.contains("nasa_application/")
                    DEPLOY_PROD = CHANGED.contains("prod_application/")
                }
            }
        }

        stage("Deploy NASA") {
            when { expression { DEPLOY_NASA } }
            steps {
                sh """
                aws ssm send-command \
                  --instance-ids ${INSTANCE_ID} \
                  --document-name AWS-RunShellScript \
                  --parameters commands="/home/ubuntu/deploy.sh nasa" \
                  --region ${AWS_REGION}
                """
            }
        }

        stage("Deploy PROD") {
            when { expression { DEPLOY_PROD } }
            steps {
                sh """
                aws ssm send-command \
                  --instance-ids ${INSTANCE_ID} \
                  --document-name AWS-RunShellScript \
                  --parameters commands="/home/ubuntu/deploy.sh prod" \
                  --region ${AWS_REGION}
                """
            }
        }
    }
}

