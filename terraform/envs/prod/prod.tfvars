# PROD — 2 pairs (demonstrates 1:1 scaling), per-AZ NAT for HA, long retention.
environment = "prod"
region      = "us-east-1"
vpc_cidr    = "10.30.0.0/16"

publish_pair_count       = 2
author_instance_type     = "t3.xlarge"
publish_instance_type    = "t3.large"
dispatcher_instance_type = "t3.small"

# Per-AZ NAT (no single point of failure) in production.
single_nat_gateway = false

# Production: no direct Author access; reach it only via the ALB host rule.
author_allowed_cidr_blocks = []
alb_allowed_cidr_blocks    = ["0.0.0.0/0"]

backup_retention_count  = 30
snapshot_interval_hours = 12
