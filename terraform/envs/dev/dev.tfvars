# DEV — small, cost-conscious, single pair, short backup retention.
environment = "dev"
region      = "us-east-1"
vpc_cidr    = "10.10.0.0/16"

publish_pair_count       = 2
author_instance_type     = "t3.xlarge"
publish_instance_type    = "t3.large"
dispatcher_instance_type = "t3.small"

single_nat_gateway = true

# Non-prod: optionally allow your office/home IP straight to Author for debugging
# (leave empty to reach Author only through the ALB host rule).
author_allowed_cidr_blocks = []
alb_allowed_cidr_blocks    = ["0.0.0.0/0"]

backup_retention_count  = 3
snapshot_interval_hours = 24
