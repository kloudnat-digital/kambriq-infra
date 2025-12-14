locals {
  name_prefix = "${var.project_name}-bastion-${var.env}"
}

# ============================================================================
# Data Sources
# ============================================================================

# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================================
# Security Group for Bastion
# ============================================================================

resource "aws_security_group" "bastion" {
  name        = local.name_prefix
  description = "Security group for bastion host (${var.env})"
  vpc_id      = var.vpc_id

  # SSH ingress from allowed CIDR blocks
  ingress {
    description = "SSH from allowed CIDR blocks"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # Egress to RDS PostgreSQL (dev and prod)
  dynamic "egress" {
    for_each = var.rds_security_group_ids
    content {
      description     = "PostgreSQL to RDS (${egress.key + 1})"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [egress.value]
    }
  }

  # Egress for package installation and git clone
  egress {
    description = "HTTPS for package installation and git"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress for HTTP (package repositories)
  egress {
    description = "HTTP for package repositories"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress for DNS
  egress {
    description = "DNS"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.name_prefix
    Env  = var.env
    Type = "bastion"
  }
}

# ============================================================================
# Security Group Rules: Allow Bastion to RDS (dev and prod)
# ============================================================================
# Add ingress rules to RDS Security Groups to allow access from bastion
# This is a non-destructive addition (doesn't modify existing rules)

resource "aws_security_group_rule" "rds_from_bastion" {
  for_each                 = toset(var.rds_security_group_ids)
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = each.value
  description              = "PostgreSQL from bastion host (shared)"
}

# ============================================================================
# Elastic IP for Bastion (to keep same public IP after restart)
# ============================================================================

resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-eip"
    Env  = var.env
    Type = "bastion"
  }
}

# ============================================================================
# IAM Role for Bastion (to associate Elastic IP via AWS CLI)
# ============================================================================

resource "aws_iam_role" "bastion" {
  name = "${local.name_prefix}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-role"
    Env  = var.env
  }
}

resource "aws_iam_role_policy" "bastion_eip" {
  name = "${local.name_prefix}-eip-policy"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AssociateAddress",
          "ec2:DescribeAddresses",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for SSM Parameter Store access
resource "aws_iam_role_policy" "bastion_ssm" {
  name = "${local.name_prefix}-ssm-policy"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter/kambriq/dev/*",
          "arn:aws:ssm:${var.aws_region}:*:parameter/kambriq/prod/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${local.name_prefix}-profile"
  role = aws_iam_role.bastion.name

  tags = {
    Name = "${local.name_prefix}-profile"
    Env  = var.env
  }
}

# ============================================================================
# Launch Template for Bastion
# ============================================================================

resource "aws_launch_template" "bastion" {
  name_prefix   = "${local.name_prefix}-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.bastion_key_pair_name

  vpc_security_group_ids = [aws_security_group.bastion.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.bastion.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get upgrade -y
    
    # Install base utilities
    apt-get install -y \
      curl \
      ca-certificates \
      gnupg \
      lsb-release \
      unzip \
      jq \
      git \
      postgresql-client
    
    # Install AWS CLI v2
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
    aws --version
    
    # Install Node.js 22 (or fallback to 20 LTS)
    if curl -fsSL https://deb.nodesource.com/setup_22.x | bash -; then
      apt-get install -y nodejs
    else
      # Fallback to Node.js 20 LTS
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
      apt-get install -y nodejs
    fi
    
    # Enable corepack for pnpm
    corepack enable
    
    # Install pnpm v9
    corepack prepare pnpm@9 --activate
    
    # Verify installations
    node --version
    pnpm --version
    git --version
    psql --version
    aws --version
    
    # Configure environment variables for ubuntu user
    # Create a script that loads DATABASE_URL from SSM on login
    # The bastion is shared between dev and prod, so allow switching environments
    # Note: Using $$ to escape $ for Terraform (so shell interprets variables at runtime)
    cat > /home/ubuntu/.bashrc_bastion <<BASHRC_EOF
# Bastion-specific environment variables
# This bastion is shared between dev and prod environments
# Default environment is dev, but can be changed with: export ENV=prod

# Default to dev if not set
if [ -z "$$ENV" ]; then
  export ENV=dev
fi

# Function to switch environment
switch_env() {
  if [ "$$1" = "dev" ] || [ "$$1" = "prod" ]; then
    export ENV=$$1
    refresh_db_url
    echo "✅ Switched to environment: $$ENV"
  else
    echo "❌ Invalid environment. Use 'dev' or 'prod'"
    echo "Usage: switch_env dev|prod"
  fi
}

# DATABASE_URL is loaded from SSM Parameter Store based on ENV variable
refresh_db_url() {
  export DATABASE_URL=$$(aws ssm get-parameter \\
    --name "/kambriq/$${ENV}/api/DATABASE_URL" \\
    --with-decryption \\
    --region eu-central-1 \\
    --query 'Parameter.Value' \\
    --output text 2>/dev/null || echo "")
  if [ -n "$$DATABASE_URL" ]; then
    echo "✅ DATABASE_URL loaded for environment: $$ENV"
  else
    echo "⚠️  Could not load DATABASE_URL for environment: $$ENV"
  fi
}

# Export other useful variables
export AWS_REGION=eu-central-1

# Load DATABASE_URL on login
refresh_db_url
BASHRC_EOF
    
    # Append to .bashrc if not already present
    if ! grep -q "bashrc_bastion" /home/ubuntu/.bashrc; then
      echo "" >> /home/ubuntu/.bashrc
      echo "# Load bastion-specific environment variables" >> /home/ubuntu/.bashrc
      echo "source /home/ubuntu/.bashrc_bastion" >> /home/ubuntu/.bashrc
    fi
    
    # Set ownership
    chown ubuntu:ubuntu /home/ubuntu/.bashrc_bastion
    chmod 644 /home/ubuntu/.bashrc_bastion
    
    # Export DATABASE_URL for dev environment at startup (default)
    # This ensures DATABASE_URL is available immediately, not just after login
    export ENV=dev
    export DATABASE_URL=$$(aws ssm get-parameter \\
      --name "/kambriq/dev/api/DATABASE_URL" \\
      --with-decryption \\
      --region eu-central-1 \\
      --query 'Parameter.Value' \\
      --output text 2>/dev/null || echo "")
    
    # Also add to /etc/environment for system-wide availability
    if [ -n "$$DATABASE_URL" ]; then
      echo "DATABASE_URL=$$DATABASE_URL" >> /etc/environment
      echo "ENV=dev" >> /etc/environment
      echo "AWS_REGION=eu-central-1" >> /etc/environment
    fi
    
    # Associate Elastic IP to this instance
    # Get instance ID from metadata
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    
    # Function to associate EIP with retries
    associate_eip() {
      local max_attempts=5
      local attempt=1
      local wait_time=15
      
      # Get EIP allocation ID from tag (EIP is tagged with Name = "${local.name_prefix}-eip")
      EIP_ALLOCATION_ID=$(aws ec2 describe-addresses \
        --filters "Name=tag:Name,Values=${local.name_prefix}-eip" \
        --query 'Addresses[0].AllocationId' \
        --output text \
        --region $REGION 2>/dev/null)
      
      if [ -z "$EIP_ALLOCATION_ID" ] || [ "$EIP_ALLOCATION_ID" = "None" ] || [ "$EIP_ALLOCATION_ID" = "null" ]; then
        echo "⚠️  EIP not found with tag Name=${local.name_prefix}-eip"
        return 1
      fi
      
      echo "📌 Found EIP Allocation ID: $EIP_ALLOCATION_ID"
      
      # Wait for instance to be fully ready (network interface must be available)
      echo "⏳ Waiting for instance to be ready..."
      sleep $wait_time
      
      # Retry association with exponential backoff
      while [ $attempt -le $max_attempts ]; do
        echo "🔄 Attempt $attempt/$max_attempts: Associating EIP to instance $INSTANCE_ID..."
        
        # Check if EIP is already associated to this instance
        CURRENT_INSTANCE=$(aws ec2 describe-addresses \
          --allocation-ids $EIP_ALLOCATION_ID \
          --query 'Addresses[0].InstanceId' \
          --output text \
          --region $REGION 2>/dev/null)
        
        if [ "$CURRENT_INSTANCE" = "$INSTANCE_ID" ]; then
          echo "✅ EIP is already associated to this instance"
          return 0
        fi
        
        # Try to associate
        if aws ec2 associate-address \
          --instance-id $INSTANCE_ID \
          --allocation-id $EIP_ALLOCATION_ID \
          --allow-reassociation \
          --region $REGION 2>&1; then
          echo "✅ EIP successfully associated to instance $INSTANCE_ID"
          return 0
        else
          echo "⚠️  EIP association attempt $attempt failed, retrying in ${wait_time}s..."
          sleep $wait_time
          wait_time=$((wait_time * 2)) # Exponential backoff
          attempt=$((attempt + 1))
        fi
      done
      
      echo "❌ Failed to associate EIP after $max_attempts attempts"
      return 1
    }
    
    # Run association in background to not block instance startup
    associate_eip >> /var/log/eip-association.log 2>&1 &
    
    # Create a marker file to indicate setup is complete
    touch /var/log/bastion-setup-complete.log
    echo "Bastion setup completed at $(date)" >> /var/log/bastion-setup-complete.log
    echo "Instance ID: $INSTANCE_ID" >> /var/log/bastion-setup-complete.log
    echo "Region: $REGION" >> /var/log/bastion-setup-complete.log
    echo "EIP association initiated (check /var/log/eip-association.log for status)" >> /var/log/bastion-setup-complete.log
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = local.name_prefix
      Env  = var.env
      Type = "bastion"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# Auto Scaling Group for Bastion
# ============================================================================

resource "aws_autoscaling_group" "bastion" {
  name                = local.name_prefix
  vpc_zone_identifier = [var.public_subnet_id]
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_size

  launch_template {
    id      = aws_launch_template.bastion.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  # Prevent ASG from replacing instances unnecessarily
  protect_from_scale_in = false

  tag {
    key                 = "Name"
    value               = local.name_prefix
    propagate_at_launch = true
  }

  tag {
    key                 = "Env"
    value               = var.env
    propagate_at_launch = true
  }

  tag {
    key                 = "Type"
    value               = "bastion"
    propagate_at_launch = true
  }
}

# ============================================================================
# Lambda Function: Auto-stop Bastion - REMOVED
# ============================================================================
# Auto-stop functionality is now handled via ASG capacity (min/desired/max = 0,0,0)
# No need for Lambda + EventBridge anymore
#
# To stop the bastion:
#   aws autoscaling set-desired-capacity --auto-scaling-group-name <asg-name> --desired-capacity 0
#   Or via Terraform: set asg_min_size, asg_desired_size, asg_max_size to 0
#
# To start the bastion:
#   aws autoscaling set-desired-capacity --auto-scaling-group-name <asg-name> --desired-capacity 1
#   Or via Terraform: set asg_min_size, asg_desired_size, asg_max_size to 1
#
# To update user-data:
#   1. Modify the user_data in aws_launch_template.bastion
#   2. Force ASG to refresh instances:
#      aws autoscaling start-instance-refresh --auto-scaling-group-name <asg-name>
#   Or via Terraform: taint the launch template and apply
