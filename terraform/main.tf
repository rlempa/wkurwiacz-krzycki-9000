provider "aws" {
  region = var.aws_region
}

# Find latest Amazon Linux 2 ARM AMI for t4g instances
data "aws_ami" "amazon_linux_2_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Use default VPC
data "aws_vpc" "default" {
  default = true
}

# Get default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Create IAM role for SSM
resource "aws_iam_role" "ssm_role" {
  name = "ssm-t4g-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ssm-t4g-instance-role"
  }
}

# Attach the AmazonSSMManagedInstanceCore policy
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create an instance profile
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm-t4g-instance-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_security_group" "instance_sg" {
  name        = "t4g-nano-instances-sg"
  description = "Security group for t4g.nano instances"
  vpc_id      = data.aws_vpc.default.id

  # Customize security rules based on your needs
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "t4g-nano-instances-sg"
  }
}

resource "aws_instance" "t4g_instances" {
  count         = var.instance_count
  ami           = data.aws_ami.amazon_linux_2_arm.id
  instance_type = "t4g.nano"

  # Apply the SSM instance profile
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name

  # Distribute instances across available subnets
  subnet_id = tolist(data.aws_subnets.default.ids)[count.index % length(data.aws_subnets.default.ids)]

  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]

  user_data_replace_on_change = true
  user_data_base64 = base64gzip(<<-EOF
    #cloud-config
    write_files:
      - path: /tmp/startup-script.sh.b64
        content: ${filebase64(var.startup_script)}
        permissions: '0755'
    runcmd:
      - cat /tmp/startup-script.sh.b64 | base64 -d > /tmp/startup-script.sh
      - exec bash /tmp/startup-script.sh --auto-adjust
  EOF
  )

  tags = {
    Name = "wk9000-${count.index}"
  }
}
