# ecs-express-terraform

Minimal end-to-end example: Spring Boot "Hello World" → Docker image → ECR → ECS Fargate (no ALB), driven by a single GitHub Actions workflow that passes the Git SHA from the build job to the Terraform apply.

## Layout

- `app/` — Spring Boot 3 (Java 21) hello-world + Dockerfile.
- `infra/` — Terraform: ECR repo, ECS cluster/service/task definition on Fargate, security group, log group, IAM task-execution role. Uses the default VPC. State in S3 bucket `pgr301-terraform-state`.
- `.github/workflows/deploy.yml` — three sequential jobs: `ensure-ecr` → `build-push` → `deploy`.

## One-time setup

1. In the AWS account, create an IAM user with programmatic access. Attach a policy covering: ECR, ECS, IAM (role + attachments for the task role), S3 (read/write on the state bucket), CloudWatch Logs, EC2 describe (VPC / subnets / SGs).
2. Add these GitHub repo secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
3. Make sure the account has a default VPC in `eu-west-1`.

## Deploy

Push to `main`. The workflow:

1. **ensure-ecr** — `terraform apply -target=aws_ecr_repository.app` so the repository exists before the build job tries to push. Idempotent on later runs.
2. **build-push** — `docker build ./app` and push `:${{ github.sha }}` to ECR.
3. **deploy** — `terraform apply -var "image_tag=<sha>"` rolls the ECS service onto the new task-def revision.

## Verify

```sh
# Image exists
aws ecr describe-images --repository-name hello-world --region eu-west-1

# Service converged
aws ecs describe-services --cluster hello-world --services hello-world --region eu-west-1 \
  --query 'services[0].{desired:desiredCount,running:runningCount,rollout:deployments[0].rolloutState}'

# Public IP of the running task
TASK_ARN=$(aws ecs list-tasks --cluster hello-world --service-name hello-world --region eu-west-1 --query 'taskArns[0]' --output text)
ENI=$(aws ecs describe-tasks --cluster hello-world --tasks "$TASK_ARN" --region eu-west-1 \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI" --region eu-west-1 \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
curl "http://$IP:8080/"
```

Expected response: `Hello World`.

## Teardown

```sh
cd infra
terraform destroy -var "image_tag=unused"
```
