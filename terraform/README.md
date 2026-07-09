# terraform — AWS infrastructure

Reusable modules (`modules/`) plus per-environment roots (`envs/`, Phase 5) that
provision one AEM environment: network + Author + N Publish/Dispatcher pairs +
ALB + backups. Environments differ only by tfvars.

## Modules

| Module | Provisions |
|---|---|
| `network/` | VPC, public/private subnets across AZs, IGW, NAT (single or per-AZ), route tables, S3 gateway endpoint, SSM interface endpoints (Session Manager without a bastion) |
| `binaries/` | Private, versioned, encrypted S3 bucket + upload of the licensed AEM jar / license / dispatcher module / (optional) service pack. TLS-only bucket policy |
| `author/` | Author EC2 (AL2023, IMDSv2), encrypted root + data EBS, IAM instance profile (SSM + binaries read), security group, systemd bootstrap that pulls binaries from S3 |
| `publish-pair/` | **One** Publish + **one** Dispatcher wired 1:1 (dispatcher renders only its paired publish; flush allowed from that publish). Instantiated with `count = publish_pair_count` for elasticity |
| `alb/` | Internet-facing ALB, SG, Dispatcher target group (+ optional host-routed Author TG), HTTP/HTTPS listeners (HTTP→HTTPS redirect when an ACM cert is given) |
| `backup/` | DLM daily EBS snapshot policy (selects volumes by the `Backup` tag) + versioned S3 bucket for content-package backups |

## Design notes

- **1:1 elasticity (O3):** the env root calls `publish-pair` with
  `count = var.publish_pair_count`; changing that one variable scales Publish and
  Dispatcher together. ASG autoscaling is documented as future work.
- **No module cycle for the ALB:** target-group *attachments* are created in the
  env root, not the `alb` module, so `author`/`publish-pair` can depend on the
  ALB security group while the ALB depends on their instance IDs — no cycle.
- **Same dispatcher config as local:** the dispatcher bootstrap writes the same
  deny-by-default farm (with the `/url` clientlib rule from Phase 2), templated
  with the paired Publish IP.
- **Security baseline:** private subnets, SSM (no SSH), IMDSv2 required,
  encrypted EBS/S3, least-privilege instance roles, TLS-only binaries bucket.

## Validation

Each module is standalone-valid:

```bash
cd modules/<name> && terraform init -backend=false && terraform validate
# repo-wide formatting:
terraform fmt -recursive -check
```

All six modules pass `fmt` and `validate` (Terraform 1.15, AWS provider ~> 5.60).
`tflint`/`checkov` run in CI (Phase 6). Real `plan`/`apply` against AWS happens
in Phase 8; there is no cloud spend from validation.
