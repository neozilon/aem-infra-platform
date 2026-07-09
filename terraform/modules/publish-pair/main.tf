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
  suffix = var.pair_index
}

# --- Shared IAM (SSM + binaries read) for both nodes of the pair -------------

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pair" {
  name_prefix        = "${var.name_prefix}-pair${local.suffix}-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.pair.name
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
  role   = aws_iam_role.pair.id
  policy = data.aws_iam_policy_document.binaries_read.json
}

resource "aws_iam_instance_profile" "pair" {
  name_prefix = "${var.name_prefix}-pair${local.suffix}-"
  role        = aws_iam_role.pair.name
}

# --- Security groups ---------------------------------------------------------

# The pair's SGs reference EACH OTHER (dispatcher renders from publish; publish
# flushes the dispatcher cache), so rules live in standalone resources — inline
# ingress blocks would create a dependency cycle between the two SGs.

resource "aws_security_group" "publish" {
  name_prefix = "${var.name_prefix}-publish${local.suffix}-"
  description = "AEM Publish node (pair ${local.suffix})"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-publish${local.suffix}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "dispatcher" {
  name_prefix = "${var.name_prefix}-dispatcher${local.suffix}-"
  description = "AEM Dispatcher node (pair ${local.suffix})"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-dispatcher${local.suffix}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# Publish ingress
resource "aws_vpc_security_group_ingress_rule" "publish_from_author" {
  security_group_id            = aws_security_group.publish.id
  description                  = "Replication from Author"
  from_port                    = var.publish_port
  to_port                      = var.publish_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.author_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "publish_from_dispatcher" {
  security_group_id            = aws_security_group.publish.id
  description                  = "Rendering from the paired Dispatcher"
  from_port                    = var.publish_port
  to_port                      = var.publish_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.dispatcher.id
}

# Dispatcher ingress
resource "aws_vpc_security_group_ingress_rule" "dispatcher_from_alb" {
  security_group_id            = aws_security_group.dispatcher.id
  description                  = "HTTP from the ALB"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.alb_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "dispatcher_from_publish" {
  security_group_id            = aws_security_group.dispatcher.id
  description                  = "Cache flush from the paired Publish"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.publish.id
}

# Egress (all outbound, both nodes)
resource "aws_vpc_security_group_egress_rule" "publish_all" {
  security_group_id = aws_security_group.publish.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "dispatcher_all" {
  security_group_id = aws_security_group.dispatcher.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- Publish node ------------------------------------------------------------

resource "aws_instance" "publish" {
  ami                    = local.ami_id
  instance_type          = var.publish_instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.publish.id]
  iam_instance_profile   = aws_iam_instance_profile.pair.name

  user_data = templatefile("${path.module}/templates/publish-user-data.sh.tftpl", {
    runmode            = "publish"
    aem_port           = var.publish_port
    binaries_bucket    = var.binaries_bucket_id
    quickstart_jar_key = var.quickstart_jar_key
    license_key        = var.license_key
    service_pack_key   = var.service_pack_key
    java_version       = var.java_version
    jvm_opts           = var.publish_jvm_opts
  })

  root_block_device {
    volume_size = var.publish_root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-publish${local.suffix}"
    Role    = "publish"
    Pair    = local.suffix
    AEM     = var.aem_version
    Backup  = var.backup_tag_value
    Runmode = "publish"
  })
}

resource "aws_ebs_volume" "publish_data" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = var.publish_data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = merge(var.tags, {
    Name   = "${var.name_prefix}-publish${local.suffix}-data"
    Role   = "publish"
    Pair   = local.suffix
    Backup = var.backup_tag_value
  })
}

resource "aws_volume_attachment" "publish_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.publish_data.id
  instance_id = aws_instance.publish.id
}

# --- Dispatcher node (renders only its paired Publish) -----------------------

resource "aws_instance" "dispatcher" {
  ami                    = local.ami_id
  instance_type          = var.dispatcher_instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.dispatcher.id]
  iam_instance_profile   = aws_iam_instance_profile.pair.name

  user_data = templatefile("${path.module}/templates/dispatcher-user-data.sh.tftpl", {
    binaries_bucket    = var.binaries_bucket_id
    dispatcher_tar_key = var.dispatcher_tar_key
    publish_host       = aws_instance.publish.private_ip
    publish_port       = var.publish_port
    flush_allowed_ip   = aws_instance.publish.private_ip
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-dispatcher${local.suffix}"
    Role = "dispatcher"
    Pair = local.suffix
  })
}
