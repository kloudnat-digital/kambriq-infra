# ============================================================================
# Application Load Balancer Module - KAMBRIQ v2.0
# ============================================================================
# Creates ALB with HTTPS listener and routing rules:
# - /api/* → FastAPI Target Group
# - /* → Next.js Target Group
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.env}"
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from Internet (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
    Env  = var.env
    Type = "alb-security-group"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2                = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${local.name_prefix}-alb"
    Env  = var.env
    Type = "alb"
  }
}

# Target Group for FastAPI (API)
resource "aws_lb_target_group" "api" {
  name        = "${local.name_prefix}-api-tg"
  port        = var.api_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/api/health"
    matcher             = "200"
    protocol            = "HTTP"
  }

  deregistration_delay = 30

  tags = {
    Name = "${local.name_prefix}-api-tg"
    Env  = var.env
    Type = "alb-target-group"
  }
}

# Target Group for Next.js (Web)
resource "aws_lb_target_group" "web" {
  name        = "${local.name_prefix}-web-tg"
  port        = var.web_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    protocol            = "HTTP"
  }

  deregistration_delay = 30

  tags = {
    Name = "${local.name_prefix}-web-tg"
    Env  = var.env
    Type = "alb-target-group"
  }
}

# HTTPS Listener (only if certificate is provided)
resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != null && var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "No matching rule"
      status_code  = "404"
    }
  }
}

# HTTP Listener with redirect to HTTPS (only if certificate is provided)
resource "aws_lb_listener" "http_redirect" {
  count             = var.certificate_arn != null && var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTP Listener without redirect (only if certificate is NOT provided)
resource "aws_lb_listener" "http_forward" {
  count             = var.certificate_arn == null || var.certificate_arn == "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "No matching rule"
      status_code  = "404"
    }
  }

  lifecycle {
    create_before_destroy = false
  }
}

# Listener Rule: /api/auth/login → FastAPI Target Group
# CRITICAL: FastAPI login endpoint must be routed to FastAPI, not NextAuth
# Priority 10 (highest priority for API endpoints)
# Use HTTPS listener if certificate is available, otherwise HTTP listener
resource "aws_lb_listener_rule" "api_auth_login" {
  listener_arn = var.certificate_arn != null && var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http_forward[0].arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/auth/login"]
    }
  }
}

# Listener Rule: /api/auth/register → FastAPI Target Group
# Priority 11
resource "aws_lb_listener_rule" "api_auth_register" {
  listener_arn = var.certificate_arn != null && var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http_forward[0].arn
  priority     = 11

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/auth/register"]
    }
  }
}

# Listener Rule: /api/auth/refresh → FastAPI Target Group
# Priority 12
resource "aws_lb_listener_rule" "api_auth_refresh" {
  listener_arn = var.certificate_arn != null && var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http_forward[0].arn
  priority     = 12

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/auth/refresh"]
    }
  }
}

# Listener Rule: /api/auth/logout → FastAPI Target Group
# Priority 13
resource "aws_lb_listener_rule" "api_auth_logout" {
  listener_arn = var.certificate_arn != null && var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http_forward[0].arn
  priority     = 13

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/auth/logout"]
    }
  }
}

# Listener Rule: /api/auth/* → Next.js Target Group (NextAuth routes)
# CRITICAL: NextAuth callback routes must go to Next.js
# Priority 15 (after FastAPI auth endpoints)
# Use HTTPS listener if certificate is available, otherwise HTTP listener
resource "aws_lb_listener_rule" "nextauth" {
  listener_arn = var.certificate_arn != null && var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http_forward[0].arn
  priority     = 15

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    path_pattern {
      values = ["/api/auth/*"]
    }
  }
}

# Listener Rule: /api/* → FastAPI Target Group
# Priority 20 (after NextAuth rule)
# Use HTTPS listener if certificate is available, otherwise HTTP listener
resource "aws_lb_listener_rule" "api" {
  listener_arn = var.certificate_arn != null && var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http_forward[0].arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# Listener Rule: /* → Next.js Target Group (default)
# Priority 100 (lowest, catch-all)
# Use HTTPS listener if certificate is available, otherwise HTTP listener
resource "aws_lb_listener_rule" "web" {
  listener_arn = var.certificate_arn != null && var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http_forward[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

