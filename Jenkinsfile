pipeline {
    agent any

    stages {
        stage("Trigger Deployment on Worker via SSM") {
            steps {
                sh """
                aws ssm send-command \
                  --instance-ids i-026b3fdb2246e82a3 \
                  --document-name "AWS-RunShellScript" \
                  --parameters commands="/home/ubuntu/deploy.sh" \
                  --region ap-south-1
                """
            }
        }
    }
}

