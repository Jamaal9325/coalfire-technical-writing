# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.10.0"

  name = "my-vpc"
  cidr = "10.1.0.0/16"

  azs = ["us-east-1a", "us-east-1b"]

  public_subnets  = ["10.1.0.0/24", "10.1.1.0/24"]
  private_subnets = ["10.1.2.0/24", "10.1.3.0/24", "10.1.4.0/24", "10.1.5.0/24"]

  enable_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Bastion instance in Public Subnet 1
module "bastion1" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.0.0"

  name                        = "bastion1"
  ami                         = "ami-0c94855ba95c71c99" # Windows Server 2019
  instance_type               = "t3a.medium"
  key_name                    = "my-key-pair"
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  root_block_device = [
    {
      volume_type = "gp2"
      volume_size = 50
    }
  ]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# WpServer 1 & 2 on their appropriate subnets
module "wpserver" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.0.0"

  count         = 2
  name          = "wpserver${count.index + 1}"
  ami           = count.index == 0 ? "ami-0c9978668f8d55984" : "ami-0c9978668f8d55984"
  instance_type = "t3a.micro"
  key_name      = "my-key-pair"
  subnet_id     = element(module.vpc.private_subnets, count.index)
  root_block_device = [
    {
      volume_type = "gp2"
      volume_size = 20
    }
  ]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# ALB
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "4.1.0"

  load_balancer_name = "my-alb"
  vpc_id             = data.aws_vpc.current.id
  log_bucket_name    = "sbx-jamaal"
  subnets = [
    module.vpc.public_subnets[0],
    module.vpc.public_subnets[1],
  ]

  security_groups = [
    aws_security_group.alb_sg.id,
  ]

  http_tcp_listeners = [
    {
      port               = "443"
      protocol           = "HTTPS"
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name_prefix          = "my-tg"
      backend_protocol     = "HTTP"
      backend_port         = "80"
      target_type          = "instance"
      deregistration_delay = 15
      health_check = jsonencode({
        path                = "/health"
        matcher             = "200-399"
        interval            = 30
        timeout             = 10
        healthy_threshold   = 5
        unhealthy_threshold = 2
      })
      targets = jsonencode([
        {
          target_id = module.wpserver[0].id
          port      = 80
        }
      ])
    }
  ]
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name_prefix = "my-alb-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

 # RDS
resource "aws_db_subnet_group" "db-subnet" {
  name_prefix = "my-db-subnet-group"
  subnet_ids  = [element(module.vpc.private_subnets, 3), element(module.vpc.private_subnets, 4)]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_db_instance" "db-instance" {
  identifier              = "rds1"
  engine                  = "postgres"
  engine_version          = "11"
  instance_class          = "db.t3.micro"
  db_name                 = "RDS1"
  username                = "myuser"
  password                = "mysecretpassword"
  allocated_storage       = 20
  storage_type            = "gp2"
  max_allocated_storage   = 100
  storage_encrypted       = false
  backup_retention_period = 7
  skip_final_snapshot     = true
  publicly_accessible     = false
  vpc_security_group_ids  = [aws_security_group.rds.id]
  db_subnet_group_name    = aws_db_subnet_group.db-subnet.name
  parameter_group_name    = "default.postgres11"

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_security_group" "rds" {
  name_prefix = "rds1"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
