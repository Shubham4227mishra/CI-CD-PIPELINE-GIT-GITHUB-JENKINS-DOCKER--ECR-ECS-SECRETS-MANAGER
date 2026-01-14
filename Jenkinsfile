pipeline {
    agent any

    environment {
        AWS_REGION = "ap-south-1"
        AWS_ACCOUNT_ID = "243017877199"
        ECR_REPO = "prod-repo"
        ECR_URI = "243017877199.dkr.ecr.ap-south-1.amazonaws.com/prod-repo"

        ECS_CLUSTER = "PROD_CLUSTER"
        ECS_SERVICE = "prod_task-definition-service-3054pvfl"
        TASK_FAMILY = "prod_task-definition"
        CONTAINER_NAME = "app-demo"
    }

    stages {

        stage("Checkout Code") {
            steps {
                checkout scm
            }
        }

        stage("Build Docker Image") {
            steps {
                sh """
                docker build -t \$ECR_REPO:\$BUILD_NUMBER .
                """
            }
        }

        stage("Login to ECR") {
            steps {
                sh """
                aws ecr get-login-password --region \$AWS_REGION | docker login --username AWS --password-stdin \$AWS_ACCOUNT_ID.dkr.ecr.\$AWS_REGION.amazonaws.com
                """
            }
        }

        stage("Tag & Push Image") {
            steps {
                sh """
                docker tag \$ECR_REPO:\$BUILD_NUMBER \$ECR_URI:\$BUILD_NUMBER
                docker push \$ECR_URI:\$BUILD_NUMBER
                """
            }
        }

        stage("Register New Task Definition") {
            steps {
                sh """
                aws ecs describe-task-definition --task-definition \$TASK_FAMILY > taskdef.json

                cat taskdef.json | jq '
                  .taskDefinition
                  | del(
                      .taskDefinitionArn,
                      .revision,
                      .status,
                      .requiresAttributes,
                      .compatibilities,
                      .registeredAt,
                      .registeredBy
                    )
                  | .containerDefinitions[0].image = "'"\$ECR_URI:\$BUILD_NUMBER"'" 
                ' > new-taskdef.json

                aws ecs register-task-definition --cli-input-json file://new-taskdef.json
                """
            }
        }

        stage("Deploy to ECS") {
            steps {
                sh """
                aws ecs update-service \
                  --cluster \$ECS_CLUSTER \
                  --service \$ECS_SERVICE \
                  --task-definition \$TASK_FAMILY
                """
            }
        }
    }
}

