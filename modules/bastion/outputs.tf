output "bastion_public_ip" {
  description = "Public IP address of the bastion host (Elastic IP)"
  value       = aws_eip.bastion.public_ip
}

output "bastion_instance_id" {
  description = "EC2 Instance ID of the bastion host"
  value       = aws_instance.bastion.id
}

output "bastion_security_group_id" {
  description = "Security Group ID of the bastion host"
  value       = aws_security_group.bastion.id
}

output "bastion_ssh_command" {
  description = "SSH command to connect to the bastion (example)"
  value       = "ssh -i <private-key.pem> ubuntu@${aws_eip.bastion.public_ip}"
}

output "bastion_stop_command" {
  description = "Command to stop the bastion"
  value       = "aws ec2 stop-instances --instance-ids ${aws_instance.bastion.id} --region ${var.aws_region}"
}

output "bastion_start_command" {
  description = "Command to start the bastion"
  value       = "aws ec2 start-instances --instance-ids ${aws_instance.bastion.id} --region ${var.aws_region}"
}
