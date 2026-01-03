# ============================================================================
# PRODUCTION ENVIRONMENT
# ============================================================================
# This configuration deploys the complete AWS platform for production
# with high availability and production-grade settings.

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  # Uncomment to use S3 backend
  # backend "s3" {
  #   bucket         = "mycompany-terraform-state"
  #   key            = "prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = "prod"
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }
}

# ============================================================================
# VPC (from terraform-aws-eks-platform)
# ============================================================================

module "vpc" {
  source = "git::https://github.com/karthik-ak-dev/terraform-aws-eks-platform.git//terraform/modules/vpc?ref=v1.0.0"

  name               = var.project_name
  vpc_cidr           = var.vpc_cidr
  az_count           = 3                  # Multi-AZ for production
  cluster_name       = "${var.project_name}-eks-cluster"
  enable_nat_gateway = true
  single_nat_gateway = false              # HA NAT for production
  enable_flow_logs   = true               # Audit logging

  tags = var.tags
}

# ============================================================================
# EKS CLUSTER (from terraform-aws-eks-platform)
# ============================================================================

module "eks" {
  source = "git::https://github.com/karthik-ak-dev/terraform-aws-eks-platform.git//terraform/modules/eks?ref=v1.0.0"

  name       = var.project_name
  vpc_id     = module.vpc.vpc_id
  vpc_cidr   = module.vpc.vpc_cidr
  subnet_ids = module.vpc.private_subnet_ids

  kubernetes_version = "1.29"

  node_groups = {
    general = {
      instance_types = ["t3.large", "t3.xlarge"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 100
      desired_size   = 3
      min_size       = 2
      max_size       = 10
    }
    spot = {
      instance_types = ["t3.large", "t3.xlarge", "m5.large"]
      capacity_type  = "SPOT"
      disk_size      = 100
      desired_size   = 2
      min_size       = 0
      max_size       = 20
      labels = {
        "node-type" = "spot"
      }
      taints = [
        {
          key    = "spot"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }

  application_roles = var.application_roles

  tags = var.tags
}

# ============================================================================
# ALB CONTROLLER (from terraform-aws-eks-platform)
# ============================================================================

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

module "alb_controller" {
  source = "git::https://github.com/karthik-ak-dev/terraform-aws-eks-platform.git//terraform/modules/alb-controller?ref=v1.0.0"

  cluster_name                  = module.eks.cluster_name
  vpc_id                        = module.vpc.vpc_id
  region                        = var.region
  iam_role_arn                  = module.eks.alb_controller_role_arn
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
  enable_https                  = true

  depends_on = [module.eks]
}

# ============================================================================
# ECR (from terraform-aws-eks-platform)
# ============================================================================

module "ecr" {
  source = "git::https://github.com/karthik-ak-dev/terraform-aws-eks-platform.git//terraform/modules/ecr?ref=v1.0.0"

  project_name     = var.project_name
  repository_names = ["services"]
  scan_on_push     = true
  max_image_count  = 500

  tags = var.tags
}

# ============================================================================
# CI/CD (from terraform-aws-eks-platform)
# ============================================================================

module "cicd" {
  source = "git::https://github.com/karthik-ak-dev/terraform-aws-eks-platform.git//terraform/modules/ci-cd?ref=v1.0.0"

  project_name     = var.project_name
  repository_names = ["services"]

  create_github_oidc_provider = false  # Already created in dev
  github_oidc_provider_arn    = var.github_oidc_provider_arn
  create_github_actions_role  = true
  github_repositories         = var.github_repositories

  tags = var.tags
}

# ============================================================================
# DATABASE (from terraform-aws-data-services)
# ============================================================================

module "aurora" {
  source = "git::https://github.com/karthik-ak-dev/terraform-aws-data-services.git//modules/aurora-postgres?ref=v1.0.0"

  name            = var.project_name
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = module.vpc.vpc_cidr
  subnet_ids      = module.vpc.private_subnet_ids
  master_password = var.db_password

  instance_class = "db.r6g.large"
  instance_count = 2  # Multi-AZ

  tags = var.tags
}

# ============================================================================
# CACHE (from terraform-aws-data-services)
# ============================================================================

module "cache" {
  source = "git::https://github.com/karthik-ak-dev/terraform-aws-data-services.git//modules/redis?ref=v1.0.0"

  name       = var.project_name
  vpc_id     = module.vpc.vpc_id
  vpc_cidr   = module.vpc.vpc_cidr
  subnet_ids = module.vpc.private_subnet_ids

  node_type          = "cache.r6g.large"
  num_cache_clusters = 2  # Multi-AZ
  auth_token         = var.redis_auth_token

  tags = var.tags
}
