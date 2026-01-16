pipeline {
    agent any

    environment {
        AWS_REGION = "ap-south-1"
        INSTANCE_ID = "i-026b3fdb2246e82a3"
        NOTIFY_EMAIL = "your-email@gmail.com"
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
                    def diffRange = ""

                    if (env.GIT_PREVIOUS_SUCCESSFUL_COMMIT) {
                        diffRange = "${env.GIT_PREVIOUS_SUCCESSFUL_COMMIT} ${env.GIT_COMMIT}"
                        echo "Diffing from last successful commit: ${diffRange}"
                    } else {
                        diffRange = "HEAD~50 HEAD"
                        echo "No previous successful commit found. Using fallback range: ${diffRange}"
                    }

                    def changedFiles = sh(
                        script: "git diff --name-only ${diffRange}",
                        returnStdout: true
                    ).trim()

                    echo "Changed files since last successful build:\n${changedFiles}"

                    env.DEPLOY_PROD = changedFiles.contains("prod_application/") ? "true" : "false"
                    env.DEPLOY_NASA = changedFiles.contains("nasa_application/") ? "true" : "false"

                    echo "DEPLOY_PROD = ${env.DEPLOY_PROD}"
                    echo "DEPLOY_NASA = ${env.DEPLOY_NASA}"
                }
            }
        }

        stage("Deploy NASA") {
            when { expression { env.DEPLOY_NASA == "true" } }
            steps {
                script {
                    runSSM("nasa")
                }
            }
        }

        stage("Approve PROD Deployment") {
            when { expression { env.DEPLOY_PROD == "true" } }
            steps {
                script {
                    emailext(
                        subject: "Approval needed: PROD deployment",
                        to: env.NOTIFY_EMAIL,
                        body: """
PROD deployment requires approval.

Job: ${env.JOB_NAME}
Build: ${env.BUILD_NUMBER}
Commit: ${env.GIT_COMMIT}

Open Jenkins and approve the deployment.
"""
                    )

                    timeout(time: 2, unit: 'HOURS') {
                        input message: "Approve deployment to PROD?", ok: "Deploy to PROD"
                    }
                }
            }
        }

        stage("Deploy PROD") {
            when { expression { env.DEPLOY_PROD == "true" } }
            steps {
                script {
                    runSSM("prod")
                }
            }
        }
    }

    post {
        success {
            emailext(
                subject: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                to: env.NOTIFY_EMAIL,
                body: "Deployment pipeline completed successfully."
            )
        }
        failure {
            emailext(
                subject: "FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                to: env.NOTIFY_EMAIL,
                body: "Deployment pipeline failed. Check Jenkins console."
            )
        }
    }
}

def runSSM(service) {
    def cmd = sh(
        script: """
        aws ssm send-command \
          --instance-ids ${INSTANCE_ID} \
          --document-name AWS-RunShellScript \
          --parameters commands="cd /home/ubuntu/project && ./deploy.sh ${service}" \
          --region ${AWS_REGION} \
          --query Command.CommandId \
          --output text
        """,
        returnStdout: true
    ).trim()

    echo "SSM Command ID: ${cmd}"

    def status = "Pending"

    while (status == "Pending" || status == "InProgress") {
        sleep 5
        status = sh(
            script: """
            aws ssm get-command-invocation \
              --command-id ${cmd} \
              --instance-id ${INSTANCE_ID} \
              --region ${AWS_REGION} \
              --query Status \
              --output text
            """,
            returnStdout: true
        ).trim()

        echo "Current SSM status: ${status}"
    }

    if (status != "Success") {
        sh """
        aws ssm get-command-invocation \
          --command-id ${cmd} \
          --instance-id ${INSTANCE_ID} \
          --region ${AWS_REGION}
        """
        error("Deployment failed on worker")
    }

    echo "Deployment succeeded for ${service}"
}

