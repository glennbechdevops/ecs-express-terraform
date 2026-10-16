# ECS with Terraform

Minimal end-to-end example: Spring Boot "Hello World" → Docker image → ECR → ECS Fargate (no ALB), driven by a GitHub Actions workflow that passes the full image URI from the build job to the Terraform apply.

## Layout

- `app/` — Spring Boot 3 (Java 21) hello-world + Dockerfile.
- `infra/` — Terraform: ECS cluster/service/task definition on Fargate, security group, log group, IAM task-execution role. Uses the default VPC. State in S3 bucket `pgr301-terraform-state`. **ECR repo is NOT managed here** — it must exist before CI runs.
- `.github/workflows/deploy.yml` — two sequential jobs: `build-push` → `deploy`.
- `.github/workflows/smoketest.yml` — on-demand curl against a URL.

## One-time setup

1. Create the ECR repository (any way you like):

   ```sh
   aws ecr create-repository --repository-name hello-world --region eu-west-1
   ```

2. In the AWS account, create an IAM user with programmatic access. Attach a policy covering: ECR (push/pull), ECS, IAM (role + attachments for the task role), S3 (read/write on the state bucket), CloudWatch Logs, EC2 describe (VPC / subnets / SGs).
3. Add these GitHub repo secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.
4. Make sure the account has a default VPC in `eu-west-1`.

## Deploy

Push to `main`. The workflow:

1. **build-push** — logs into ECR, builds `./app`, pushes `<registry>/hello-world:${{ github.sha }}`. Exposes the full image URI as the job output `image`.
2. **deploy** — `terraform apply -var "image=<URI>"` rolls the ECS service onto the new task-def revision.

## Verify

You can see the IP address and port in the AWS ECS console. Find the cluster, navigate to the service, then find the task.
Or you can do it the DevOps way :)

```sh
aws ecs describe-services --cluster hello-world --services hello-world --region eu-west-1 \
  --query 'services[0].{desired:desiredCount,running:runningCount,rollout:deployments[0].rolloutState}'

TASK_ARN=$(aws ecs list-tasks --cluster hello-world --service-name hello-world --region eu-west-1 --query 'taskArns[0]' --output text)
ENI=$(aws ecs describe-tasks --cluster hello-world --tasks "$TASK_ARN" --region eu-west-1 \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI" --region eu-west-1 \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
curl "http://$IP:8080/"
```

Expected: `Hello World`. (Some networks block outbound 8080 via DPI — hit from a phone hotspot or the `smoketest` workflow if local curl resets.)

## Teardown

```sh
cd infra
terraform destroy -var "image=unused"
# ECR repo is not managed by TF; delete it manually if desired:
aws ecr delete-repository --repository-name hello-world --region eu-west-1 --force
```
