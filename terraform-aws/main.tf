terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
        tls = {
            source = "hashicorp/tls"
            version = "~> 4.0"
        }
        local = {
            source = "hashicorp/local"
            version = "~> 2.0"
        }
    }
    required_version = ">= 1.3.0"
}

provider "aws" {
    region = var.aws_region
}

# --- Data Sources ---
data "aws_ami" "amazon_linux_2023" {
    most_recent = true
    owners      = ["amazon"]

    filter {
        name   = "name"
        values = ["al2023-ami-*-kernel-6.1-x86_64"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
}

data "aws_vpc" "default" {
    default = true
}

resource "tls_private_key" "ec2_key" {
    algorithm = "RSA"
    rsa_bits = 4096
}

resource "aws_key_pair" "ec2_key_pair" {
    key_name = "${var.project_name}-key"
    public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "local_file" "private_key" {
    content = tls_private_key.ec2_key.private_key_pem
    filename = "${path.module}/${var.project_name}-key.pem"
    file_permission = "0400"
}

resource "aws_iam_role" "ec2_role" {
    name = "${var.project_name}-ec2-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = { Service = "ec2.amazonaws.com" }
        }]
    })
}

# attach ECR read policy to role
resource "aws_iam_role_policy_attachment" "ecr_policy" {
    role = aws_iam_role.ec2_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

#instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
    name = "${var.project_name}-ec2-profile"
    role = aws_iam_role.ec2_role.name
}

# --- Security Group for EC2 ---
resource "aws_security_group" "ec2_sg" {
    name        = "${var.project_name}-sg"
    description = "Security group for EC2 instance"
    vpc_id      = data.aws_vpc.default.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name    = "${var.project_name}-sg"
        Project = var.project_name
    }
}

# --- EC2 Instance (t3.small) ---
resource "aws_instance" "app_server" {
    ami                    = data.aws_ami.amazon_linux_2023.id
    instance_type          = "t3.small"
    vpc_security_group_ids = [aws_security_group.ec2_sg.id]
    key_name = aws_key_pair.ec2_key_pair.key_name
    associate_public_ip_address = true
    iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

    root_block_device {
        volume_size = 40
        volume_type = "gp3"
        encrypted   = true
    }

    metadata_options {
        http_tokens = "required" # IMDSv2 enforced
    }

    user_data = base64encode(join("\n", [
        "#!/bin/bash",
        "set -e",

        "yum update -y",
        "dd if=/dev/zero of=/swapfile bs=128M count=16",
        "chmod 600 /swapfile",
        "mkswap /swapfile",
        "swapon /swapfile",
        "echo '/swapfile swap swap defaults 0 0' >> /etc/fstab",
        "curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true sh -s - server --disable traefik --disable servicelb --disable metrics-server --write-kubeconfig-mode 644",

        "systemctl enable k3s",
        "systemctl start k3s",

        "sleep 120",

        "/usr/local/bin/k3s kubectl get nodes || true"
    ]))

    tags = {
        Name    = "${var.project_name}-server"
        Project = var.project_name
    }
}

# --- ECR Repository ---
resource "aws_ecr_repository" "app_repo" {
    name                 = "${var.project_name}-repo"
    image_tag_mutability = "IMMUTABLE"

    force_delete = true

    image_scanning_configuration {
        scan_on_push = true
    }

    encryption_configuration {
        encryption_type = "AES256"
    }

    tags = {
        Name    = "${var.project_name}-repo"
        Project = var.project_name
    }
}

# ECR Lifecycle Policy — keep last 10 images
resource "aws_ecr_lifecycle_policy" "app_repo_policy" {
    repository = aws_ecr_repository.app_repo.name

    policy = jsonencode({
        rules = [{
            rulePriority = 1
            description  = "Keep last 10 images"
            selection = {
                tagStatus   = "any"
                countType   = "imageCountMoreThan"
                countNumber = 10
            }
            action = { type = "expire" }
        }]
    })
}