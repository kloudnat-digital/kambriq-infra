# ============================================================================
# CloudFront Distribution Module V2 - KAMBRIQ v2.0
# ============================================================================
# Creates CloudFront distribution with ALB as origin
# Cache behaviors:
# - /api/* → ALB (no cache, forward all headers)
# - /* → ALB (cache static assets, no cache for SSR)
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.env}"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "KAMBRIQ ${var.env} v2.0 - CloudFront → ALB"
  default_root_object = ""

  aliases = var.domain_name != "" ? [var.domain_name] : []

  # Origin: ALB
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Forwarded-Host"
      value = var.domain_name != "" ? var.domain_name : var.alb_dns_name
    }
  }

  # Cache Behavior: /api/* (no cache)
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    target_origin_id = "alb-origin"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }

    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Default Cache Behavior: /* (cache static, no cache SSR)
  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["Host", "Accept", "Accept-Language", "Accept-Encoding", "Authorization", "Cookie"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 3600  # Cache static assets
    max_ttl     = 86400
    compress    = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn != "" ? var.certificate_arn : null
    ssl_support_method       = var.certificate_arn != "" ? "sni-only" : "default"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = "${local.name_prefix}-cf-v2"
    Env  = var.env
    Type = "cloudfront-v2"
  }
}

