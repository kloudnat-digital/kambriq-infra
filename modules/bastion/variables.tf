variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "kambriq"
}

variable "vpc_id" {
  description = "VPC ID where the bastion will be deployed"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for bastion placement"
  type        = string
}

variable "rds_security_group_ids" {
  description = "List of Security Group IDs of RDS instances (dev and prod) to allow access from bastion"
  type        = list(string)
  default     = []
}

variable "bastion_key_pair_name" {
  description = "Name of the existing EC2 Key Pair for SSH access (must exist in AWS)"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "List of CIDR blocks allowed to SSH into the bastion (e.g., ['1.2.3.4/32', '5.6.7.8/32']). Required when bastion is enabled."
  type        = list(string)

  validation {
    condition = length(var.allowed_ssh_cidr) > 0 && alltrue([
      for cidr in var.allowed_ssh_cidr : can(cidrhost(cidr, 0))
    ])
    error_message = "allowed_ssh_cidr must be a non-empty list of valid CIDR blocks (e.g., ['1.2.3.4/32', '5.6.7.8/32'])."
  }
}

variable "instance_type" {
  description = "EC2 instance type for bastion"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of instances in ASG (0 to stop bastion, 1 to start)"
  type        = number
  default     = 1
}

variable "asg_desired_size" {
  description = "Desired number of instances in ASG (0 to stop bastion, 1 to start)"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG (should be 1 for bastion)"
  type        = number
  default     = 1
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}
