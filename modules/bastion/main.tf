data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  name_tag        = { Name = var.name }
  enable_schedule = var.schedule_stop != "" && var.schedule_start != ""

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    dnf update -y --security

    dnf install -y \
      postgresql15 \
      redis6 \
      jq \
      curl \
      wget \
      htop \
      vim \
      nmap-ncat \
      tcpdump

    # SSM Agent is pre-installed on AL2023 — ensure it is enabled
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOF
}

resource "aws_iam_role" "bastion" {
  name = "${var.name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.name_tag
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name}-profile"
  role = aws_iam_role.bastion.name

  tags = local.name_tag
}

resource "aws_security_group" "bastion" {
  name        = "${var.name}-sg"
  description = "Bastion host security group"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      description = "SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.name_tag
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = var.associate_public_ip
  key_name                    = var.key_name
  user_data                   = local.user_data
  user_data_replace_on_change = true

  tags = local.name_tag
}

# ── EventBridge Scheduler: stop bastion outside work hours ───────────────────

resource "aws_iam_role" "scheduler" {
  count = local.enable_schedule ? 1 : 0
  name  = "${var.name}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.name_tag
}

resource "aws_iam_role_policy" "scheduler" {
  count = local.enable_schedule ? 1 : 0
  name  = "${var.name}-scheduler-policy"
  role  = aws_iam_role.scheduler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:StopInstances", "ec2:StartInstances"]
      Resource = aws_instance.bastion.arn
    }]
  })
}

resource "aws_scheduler_schedule" "stop" {
  count = local.enable_schedule ? 1 : 0
  name  = "${var.name}-stop"

  flexible_time_window { mode = "OFF" }

  schedule_expression          = "cron(${var.schedule_stop})"
  schedule_expression_timezone = var.schedule_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.scheduler[0].arn
    input    = jsonencode({ InstanceIds = [aws_instance.bastion.id] })
  }
}

resource "aws_scheduler_schedule" "start" {
  count = local.enable_schedule ? 1 : 0
  name  = "${var.name}-start"

  flexible_time_window { mode = "OFF" }

  schedule_expression          = "cron(${var.schedule_start})"
  schedule_expression_timezone = var.schedule_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.scheduler[0].arn
    input    = jsonencode({ InstanceIds = [aws_instance.bastion.id] })
  }
}
