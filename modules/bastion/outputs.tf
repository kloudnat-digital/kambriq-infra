output "bastion_public_ip" {
  description = "Public IP address of the bastion host (Elastic IP)"
  value       = aws_eip.bastion.public_ip
}

output "bastion_asg_name" {
  description = "Auto Scaling Group name for the bastion"
  value       = aws_autoscaling_group.bastion.name
}

output "bastion_security_group_id" {
  description = "Security Group ID of the bastion host"
  value       = aws_security_group.bastion.id
}

output "bastion_launch_template_id" {
  description = "Launch Template ID for the bastion"
  value       = aws_launch_template.bastion.id
}

output "bastion_ssh_command" {
  description = "SSH command to connect to the bastion (example)"
  value       = "ssh -i <private-key.pem> ubuntu@${aws_eip.bastion.public_ip}"
}

output "bastion_stop_command" {
  description = "Command to stop the bastion (set ASG capacity to 0)"
  value       = "aws autoscaling set-desired-capacity --auto-scaling-group-name ${aws_autoscaling_group.bastion.name} --desired-capacity 0 --region ${var.aws_region}"
}

output "bastion_start_command" {
  description = "Command to start the bastion (set ASG capacity to 1)"
  value       = "aws autoscaling set-desired-capacity --auto-scaling-group-name ${aws_autoscaling_group.bastion.name} --desired-capacity 1 --region ${var.aws_region}"
}

output "bastion_refresh_command" {
  description = "Command to refresh ASG instances (after updating Launch Template user-data)"
  value       = "aws autoscaling start-instance-refresh --auto-scaling-group-name ${aws_autoscaling_group.bastion.name} --region ${var.aws_region}"
}
