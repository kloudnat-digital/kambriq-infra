locals {
  name_prefix = "${var.project_name}-${var.env}"
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${local.name_prefix}-redis-subnet"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${local.name_prefix}-redis-subnet"
    Env  = var.env
  }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${local.name_prefix}-redis"
  description                = "Redis replication group for ${local.name_prefix}"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  port                       = var.port
  num_cache_clusters         = 1
  multi_az_enabled           = false
  automatic_failover_enabled = false
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = var.security_group_ids
  at_rest_encryption_enabled = var.at_rest_encryption_enabled

  # D20 - in place, not a replacement. The live cluster runs Redis 7.1.0, and
  # AWS supports modifying the in-transit encryption setting of an existing
  # replication group "running Valkey 7.2 and later, and Redis OSS version 7 and
  # later"; the provider only forces replacement for engine_version < 7.0.5. So
  # the session store and the five queues survive this change - which is worth
  # stating, because on an engine below 7.0.5 the same two lines would have
  # replaced the cluster and dropped every queued job.
  transit_encryption_enabled = var.transit_encryption_enabled
  transit_encryption_mode    = var.transit_encryption_mode
  auth_token                 = var.auth_token != "" ? var.auth_token : null
  auth_token_update_strategy = var.auth_token_update_strategy
  apply_immediately          = true

  tags = {
    Name = "${local.name_prefix}-redis"
    Env  = var.env
  }
}
