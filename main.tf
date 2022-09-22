locals {
  name                = var.stack_name
  region              = var.region
  vpc_cidr            = var.vpc_cidr
  vpc_public_subnets  = var.vpc_public_subnets
  vpc_private_subnets = var.vpc_private_subnets
  vpc_db_subnets      = var.vpc_db_subnets

  db_instance_type        = var.db_instance_type
  db_engine_version       = var.db_engine_version
  db_major_engine_version = var.db_major_engine_version
  db_size                 = var.db_size
  db_username             = var.db_username
  db_default_db_name      = var.db_default_db_name

  ec2_instance_type = var.ec2_instance_type
  ec2_ebs_vol_size  = var.ec2_ebs_vol_size


  tags = merge({
    Managed-By = "Terraform"
  }, var.tags)

  user_data = <<-EOT
  #!/bin/bash
  sudo yum update -y && sudo yum install nginx
  echo "Hello World" > /usr/share/nginx/html/index.html
  sudo systemctl enable nginx
  sudo systemctl start nginx
  EOT

}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "${local.name}-vpc"
  cidr = local.vpc_cidr

  azs              = ["${local.region}a", "${local.region}b", "${local.region}c"]
  public_subnets   = local.vpc_public_subnets
  private_subnets  = local.vpc_private_subnets
  database_subnets = local.vpc_db_subnets

  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  tags = local.tags
}

module "security_group_ec2" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "ec2_sg"
  description = "ec2_sg"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Allow access Nginx"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = local.tags
}

module "security_group_rds" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "postgresql_sg"
  description = "postgresql_sg"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "Allow access PostgreSQL from Ec2"
      cidr_blocks = module.security_group_ec2.security_group_id
    }
  ]

  tags = local.tags
}

module "postgres" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 5.1.0"

  identifier                     = "${local.name}-postgresql"
  instance_use_identifier_prefix = true

  create_db_option_group    = false
  create_db_parameter_group = false

  engine               = "postgres"
  engine_version       = local.db_engine_version
  family               = "postgres14"
  major_engine_version = local.db_major_engine_version
  instance_class       = local.db_instance_type

  allocated_storage = local.db_size

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  db_name  = local.db_default_db_name
  username = local.db_username
  port     = 5432

  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [module.security_group_rds.security_group_id]

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 0

  iam_database_authentication_enabled = true

  tags = local.tags
}

// -------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*-x86_64-gp2"]
  }
}

module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 4.1.4"

  name = "${local.name}-ec2"

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = local.ec2_instance_type
  availability_zone           = element(module.vpc.azs, 0)
  subnet_id                   = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [module.security_group_ec2.security_group_id]
  associate_public_ip_address = true
  user_data_base64            = base64encode(local.user_data)

  iam_instance_profile = aws_iam_role.ec2_role.name

  tags = local.tags
}

resource "aws_iam_role" "ec2_role" {
  name = "${local.name}_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "0"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "access-rds"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["rds-db:connect"]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }


  tags = local.tags
}


resource "aws_volume_attachment" "this" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.this.id
  instance_id = module.ec2.id
}

resource "aws_ebs_volume" "this" {
  availability_zone = element(module.vpc.azs, 0)
  size              = local.ec2_ebs_vol_size

  tags = local.tags
}

