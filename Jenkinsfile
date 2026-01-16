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
        success { echo "Pipeline completed successfully" }
        failure { echo "Pipeline failed" }
    }
}

def runSSM(service) {
    def cmd = sh(
        script: """
        aws ssm send-command \
          --instance-ids ${INSTANCE_ID} \
          --document-name AWS-RunShellScript \
          --parameters commands="/home/ubuntu/project/deploy.sh ${service}" \
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

