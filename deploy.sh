#!/bin/bash
set -e
exec > /home/ubuntu/deploy.log 2>&1

SERVICE_NAME="$1"

if [ -z "$SERVICE_NAME" ]; then
  echo "Usage: ./deploy.sh <prod|nasa>"
  exit 1
fi

AWS_REGION="ap-south-1"
ACCOUNT_ID="243017877199"
CLUSTER="PROD_CLUSTER"

if [ "$SERVICE_NAME" = "prod" ]; then
  APP_DIR="prod_application"
  ECR_REPO="prod-repo"
  TASK_FAMILY="prod_task-definition"
  SERVICE="prod_task-definition-service-3054pvfl"
elif [ "$SERVICE_NAME" = "nasa" ]; then
  APP_DIR="nasa_application"
  ECR_REPO="nasa-repo"
  TASK_FAMILY="nasa_app_definition"
  SERVICE="nasa_app_definition-service-292a5om3"
else
  echo "Unknown service: $SERVICE_NAME"
  exit 1
fi

ECR_URI="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO"
PROJECT_DIR="/home/ubuntu/project"

echo "=========================================="
echo "🚀 Deploying service: $SERVICE_NAME"
echo "=========================================="

cd $PROJECT_DIR

echo "=== Resetting repo state ==="
git reset --hard
git clean -fd

echo "=== Pulling latest code ==="
git pull origin main

VERSION=$(date +%Y%m%d%H%M%S)
echo "=== Building version $VERSION ==="

echo "=== Logging into ECR ==="
aws ecr get-login-password --region $AWS_REGION \
 | docker login --username AWS --password-stdin $ECR_URI

echo "=== Building Docker image from $APP_DIR ==="
# 🔥 FORCE rebuild so even 1 character change creates new image
docker build --no-cache -t $ECR_REPO:$VERSION $APP_DIR

echo "=== Tagging image ==="
docker tag $ECR_REPO:$VERSION $ECR_URI:$VERSION

echo "=== Pushing image ==="
docker push $ECR_URI:$VERSION

echo "=== Fetching current task definition ==="
aws ecs describe-task-definition \
  --task-definition $TASK_FAMILY \
  --region $AWS_REGION \
  --query taskDefinition > /home/ubuntu/current-taskdef.json

echo "=== Creating new task definition ==="
jq --arg IMAGE "$ECR_URI:$VERSION" '
  .containerDefinitions[0].image = $IMAGE
  | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)
' /home/ubuntu/current-taskdef.json > /home/ubuntu/new-taskdef.json

echo "=== Registering new task definition ==="
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
  --region $AWS_REGION \
  --cli-input-json file:///home/ubuntu/new-taskdef.json \
  --query "taskDefinition.taskDefinitionArn" \
  --output text)

echo "=== Updating service to new task definition ==="
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --task-definition "$NEW_TASK_DEF_ARN" \
  --region $AWS_REGION

echo "=== Waiting for service to stabilize ==="
aws ecs wait services-stable \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region $AWS_REGION

echo "=========================================="
echo "✅ Deployment completed for $SERVICE_NAME"
echo "=========================================="

