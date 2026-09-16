# ============================================================================
# Application Load Balancer Module - KAMBRIQ v2.0
# ============================================================================
# Creates ALB with HTTPS listener and routing rules:
# - /api/* → API Target Group (NestJS backend routes)
# - /* → Web Target Group (SSR pages, static assets)
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

  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  dynamic "access_logs" {
    for_each = var.access_logs_bucket != "" ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = "${local.name_prefix}-alb"
      enabled = true
    }
  }

  tags = {
    Name = "${local.name_prefix}-alb"
    Env  = var.env
    Type = "alb"
  }
}

# Target Group for API
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
    path                = "/api/v1/health/ready"
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

# Listener Rule: www.<host> → <host> (HTTPS 301 redirect)
# Priority 10 (higher than api/web catch-alls, lower than any future specialized rule)
# Only created when a cert is present AND redirect_www_to_apex_host is set.
resource "aws_lb_listener_rule" "www_redirect_https" {
  count        = var.certificate_arn != null && var.certificate_arn != "" && var.redirect_www_to_apex_host != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 10

  action {
    type = "redirect"
    redirect {
      host        = var.redirect_www_to_apex_host
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = ["www.${var.redirect_www_to_apex_host}"]
    }
  }
}

# Listener Rule: www.<host> → <host> (HTTP → HTTPS apex 301 redirect)
# Overrides the default HTTP-listener redirect so www is normalized at the same time.
resource "aws_lb_listener_rule" "www_redirect_http" {
  count        = var.certificate_arn != null && var.certificate_arn != "" && var.redirect_www_to_apex_host != "" ? 1 : 0
  listener_arn = aws_lb_listener.http_redirect[0].arn
  priority     = 10

  action {
    type = "redirect"
    redirect {
      host        = var.redirect_www_to_apex_host
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = ["www.${var.redirect_www_to_apex_host}"]
    }
  }
}

# Listener Rule: /api/* → API Target Group
# Priority 1 (highest priority - API routes)
# Use HTTPS listener if certificate is available, otherwise HTTP listener
# Note: Only /api/* routes go to API. All other routes go to Web.
resource "aws_lb_listener_rule" "api_v1" {
  listener_arn = var.certificate_arn != null && var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http_forward[0].arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/*"]
    }
  }
}

# ---------------------------------------------------------------------------
# D13 - the exempt paths, ABOVE the web catch-all and above the gate.
#
# Priority 5, so they are matched before priority 100 whichever form that takes.
# These are the paths machines use: `/health` is read by deploy-dev.yml's web
# version gate on every deploy. `/api/v1/*` needs no entry here - it is already
# priority 1 and forwarded to the API target group, which is why the journeys,
# api-e2e, the smoke test and the API version gate are untouched by this change.
#
# Created only when the gate is, so that without the gate the listener is
# byte-for-byte what it was.
# ---------------------------------------------------------------------------
locals {
  # Known at plan time, deliberately. The pool ARN, client id and domain are
  # only known after apply when they come from the Cognito resources, and a
  # `count` that reads them fails with "Invalid count argument" - so the switch
  # is the bool, and the three values are checked by the variable validation
  # below rather than by the count.
  web_auth_enabled = var.web_auth_enabled && var.certificate_arn != null && var.certificate_arn != ""
}

# A gate that is switched on but not configured would create a rule pointing at
# an empty pool, which authenticates nobody and serves nobody. Refused at plan
# time instead.
check "web_auth_is_configured" {
  assert {
    condition = !var.web_auth_enabled || (
      var.web_auth_user_pool_arn != "" &&
      var.web_auth_user_pool_client_id != "" &&
      var.web_auth_user_pool_domain != ""
    )
    error_message = "web_auth_enabled is true, so web_auth_user_pool_arn, web_auth_user_pool_client_id and web_auth_user_pool_domain must all be set."
  }
}

resource "aws_lb_listener_rule" "web_auth_exempt" {
  count        = local.web_auth_enabled ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    path_pattern {
      values = var.web_auth_exempt_paths
    }
  }
}

# ---------------------------------------------------------------------------
# D13 - the gate: authenticate, then forward.
#
# Two actions in one rule. AWS performs "the action with the lowest value for
# order" first, and the provider's own example pairs authenticate-cognito with
# forward without setting `order`; the orders are set explicitly here anyway,
# because a rule that forwarded before authenticating would look identical in
# the diff and serve the site to anybody.
#
# `on_unauthenticated_request = "authenticate"` is what produces the login: the
# load balancer redirects to the Cognito authorization endpoint. `deny` would
# return 401 to the browser with no prompt, which is the dead end HTTP Basic ran
# into here.
#
# This REPLACES the unauthenticated `/*` forward when enabled - the two cannot
# both hold priority 100, and leaving the old rule in place beside this one
# would leave the site reachable.
# ---------------------------------------------------------------------------
resource "aws_lb_listener_rule" "web_authenticated" {
  count        = local.web_auth_enabled ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100

  action {
    type  = "authenticate-cognito"
    order = 1

    authenticate_cognito {
      user_pool_arn              = var.web_auth_user_pool_arn
      user_pool_client_id        = var.web_auth_user_pool_client_id
      user_pool_domain           = var.web_auth_user_pool_domain
      on_unauthenticated_request = "authenticate"
      scope                      = "openid email"
      session_cookie_name        = "AWSELBAuthSessionCookie-kambriq-dev"
      session_timeout            = var.web_auth_session_timeout
    }
  }

  action {
    type             = "forward"
    order            = 2
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

# Listener Rule: /* → Next.js Target Group (default)
# Priority 100 (lowest, catch-all)
# Use HTTPS listener if certificate is available, otherwise HTTP listener
#
# D13: created only while the gate is NOT enabled. With the gate on, the
# authenticated rule takes priority 100 and this one must not exist.
resource "aws_lb_listener_rule" "web" {
  count        = local.web_auth_enabled ? 0 : 1
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

