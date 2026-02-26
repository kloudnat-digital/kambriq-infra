variable "name" {
  type        = string
  description = "Bastion name prefix"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the bastion"
}

variable "public_subnet_id" {
  type        = string
  description = "Public subnet ID for the bastion"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "associate_public_ip" {
  type        = bool
  description = "Associate a public IP with the bastion"
  default     = true
}

variable "key_name" {
  type        = string
  description = "SSH key pair name"
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to SSH into the bastion"
  default     = []
}

variable "enable_ssh" {
  type        = bool
  description = "Enable SSH ingress rules"
  default     = true
}
