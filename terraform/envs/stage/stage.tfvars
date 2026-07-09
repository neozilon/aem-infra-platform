# STAGE — prod-like topology, single pair, medium backup retention.
environment = "stage"
region      = "us-east-1"
vpc_cidr    = "10.20.0.0/16"

publish_pair_count       = 1
author_instance_type     = "t3.xlarge"
publish_instance_type    = "t3.large"
dispatcher_instance_type = "t3.small"

single_nat_gateway = true

author_allowed_cidr_blocks = []
alb_allowed_cidr_blocks    = ["0.0.0.0/0"]

backup_retention_count  = 7
snapshot_interval_hours = 24
