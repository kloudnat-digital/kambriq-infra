# ============================================================================
# LEGACY: This module is no longer used in the active KAMBRIQ infrastructure.
# It has been replaced by modules/shared which includes VPC/networking functionality.
# This module is kept for historical reference only.
# ============================================================================
#
# Pour simplifier et minimiser les coûts, on utilise la VPC par défaut
# Pour la production, on peut créer une VPC dédiée avec des sous-réseaux privés

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group pour RDS
resource "aws_security_group" "rds" {
  name        = "kambriq-rds-${var.env}"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "PostgreSQL from Lambda"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kambriq-rds-${var.env}"
    Env  = var.env
  }
}

# Security Group pour Lambda
resource "aws_security_group" "lambda" {
  name        = "kambriq-lambda-${var.env}"
  description = "Security group for Lambda functions"
  vpc_id      = data.aws_vpc.default.id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kambriq-lambda-${var.env}"
    Env  = var.env
  }
}

