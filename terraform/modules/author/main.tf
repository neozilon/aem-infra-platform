data "aws_ami" "al2023" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023[0].id
}

# --- IAM: SSM access + read-only on the binaries bucket ----------------------

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "author" {
  name_prefix        = "${var.name_prefix}-author-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.author.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "binaries_read" {
  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [var.binaries_bucket_arn]
  }
  statement {
    sid       = "GetObjects"
    actions   = ["s3:GetObject"]
    resources = ["${var.binaries_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "binaries_read" {
  name   = "binaries-read"
  role   = aws_iam_role.author.id
  policy = data.aws_iam_policy_document.binaries_read.json
}

# Tier-2 backups: allow the Author to upload content packages.
data "aws_iam_policy_document" "backup_write" {
  count = var.backup_bucket_arn != "" ? 1 : 0

  statement {
    sid       = "PutPackages"
    actions   = ["s3:PutObject"]
    resources = ["${var.backup_bucket_arn}/packages/*"]
  }
}

resource "aws_iam_role_policy" "backup_write" {
  count  = var.backup_bucket_arn != "" ? 1 : 0
  name   = "backup-write"
  role   = aws_iam_role.author.id
  policy = data.aws_iam_policy_document.backup_write[0].json
}

resource "aws_iam_instance_profile" "author" {
  name_prefix = "${var.name_prefix}-author-"
  role        = aws_iam_role.author.name
}

# --- Security group ----------------------------------------------------------

resource "aws_security_group" "author" {
  name_prefix = "${var.name_prefix}-author-"
  description = "AEM Author node"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.ingress_security_group_ids) > 0 ? [1] : []
    content {
      description     = "AEM port from allowed security groups (ALB)"
      from_port       = var.aem_port
      to_port         = var.aem_port
      protocol        = "tcp"
      security_groups = var.ingress_security_group_ids
    }
  }

  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      description = "AEM port from allowed CIDRs (non-prod)"
      from_port   = var.aem_port
      to_port     = var.aem_port
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-author-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# --- Compute + storage -------------------------------------------------------

resource "aws_instance" "author" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.author.id]
  iam_instance_profile   = aws_iam_instance_profile.author.name

  user_data = templatefile("${path.module}/../templates/aem-node-user-data.sh.tftpl", {
    runmode            = "author"
    env_runmode        = var.aem_env_runmode
    aem_port           = var.aem_port
    binaries_bucket    = var.binaries_bucket_id
    quickstart_jar_key = var.quickstart_jar_key
    license_key        = var.license_key
    service_pack_key   = var.service_pack_key
    java_version       = var.java_version
    jvm_opts           = var.jvm_opts
    install_script     = file("${path.module}/../../../scripts/install-aem.sh")
  })

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-author"
    Role    = "author"
    AEM     = var.aem_version
    Backup  = var.backup_tag_value
    Runmode = "author"
  })
}

resource "aws_ebs_volume" "data" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = var.data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = merge(var.tags, {
    Name   = "${var.name_prefix}-author-data"
    Role   = "author"
    Backup = var.backup_tag_value
  })
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.author.id
}
