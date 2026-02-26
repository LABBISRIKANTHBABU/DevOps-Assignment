terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "pgagi-terraform-state-aws-5642c847"  # <-- UPDATED HERE
    key            = "devops-assignment/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  
  default_tags {
    tags = {
      Environment = "dev"
      Project     = "pgagi-devops"
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"
  
  environment = "dev"
  vpc_cidr    = "10.0.0.0/16"
}

module "iam" {
  source = "../../modules/iam"
  
  environment = "dev"
}

module "alb" {
  source = "../../modules/alb"
  
  environment       = "dev"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

module "ecs" {
  source = "../../modules/ecs"
  
  environment                 = "dev"
  vpc_id                      = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnet_ids
  backend_target_group_arn    = module.alb.backend_target_group_arn
  frontend_target_group_arn   = module.alb.frontend_target_group_arn
  alb_security_group_id       = module.alb.alb_security_group_id
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.iam.ecs_task_role_arn
}

output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "DNS name of the load balancer"
}

output "ecr_backend_repo" {
  value       = module.ecs.backend_ecr_repository_url
  description = "Backend ECR repository URL"
}

output "ecr_frontend_repo" {
  value       = module.ecs.frontend_ecr_repository_url
  description = "Frontend ECR repository URL"
}