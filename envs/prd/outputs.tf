output "alb_dns_name" {
  description = "Prod ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  description = "Prod ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "rds_endpoint" {
  description = "Prod RDS endpoint"
  value       = module.rds.db_host
}

output "nat_gateway_id" {
  description = "Prod NAT gateway"
  value       = aws_nat_gateway.prod.id
}

output "private_subnet_ids" {
  description = "Prod private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Prod public subnets"
  value       = aws_subnet.public[*].id
}

# throwaway: touch only envs/prd to prove Plan (prd) runs. Reverted before merge.
