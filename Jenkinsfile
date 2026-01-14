sh '''
set -x
aws ssm send-command \
  --instance-ids i-026b3fdb2246e82a3 \
  --document-name AWS-RunShellScript \
  --parameters commands="/home/ubuntu/deploy.sh" \
  --region ap-south-1 \
  --no-cli-pager \
  > /tmp/ssm_out.json

cat /tmp/ssm_out.json
'''

