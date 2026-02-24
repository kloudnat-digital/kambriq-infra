output "primary_endpoint_address" {
  description = "Primary endpoint address for Redis"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.main.port
}

output "replication_group_id" {
  description = "ElastiCache replication group ID"
  value       = aws_elasticache_replication_group.main.id
}
