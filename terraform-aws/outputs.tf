output "ec2_instance_id" {
    description = "EC2 instance ID"
    value       = aws_instance.app_server.id
}

output "ec2_public_ip" {
    description = "EC2 public IP address"
    value       = aws_instance.app_server.public_ip
}

output "ec2_instance_state" {
    description = "EC2 instance state"
    value       = aws_instance.app_server.instance_state
}

output "ecr_repository_url" {
    description = "ECR repository URL"
    value       = aws_ecr_repository.app_repo.repository_url
}

output "ecr_repository_arn" {
    description = "ECR repository ARN"
    value       = aws_ecr_repository.app_repo.arn
}