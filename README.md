# Terraform AWS Infrastructure

Production AWS infrastructure deployment using modular Terraform. This repository demonstrates how to compose reusable modules into complete, environment-specific configurations.

## Overview

This is the **main infrastructure repository** that orchestrates deployments by consuming modules from:

| Module Repository | Purpose |
|------------------|---------|
| [terraform-aws-organization](https://github.com/karthik-ak-dev/terraform-aws-organization) | AWS Organizations, IAM Identity Center |
| [terraform-aws-eks-platform](https://github.com/karthik-ak-dev/terraform-aws-eks-platform) | VPC, EKS, ALB Controller, ECR, CI/CD |
| [terraform-aws-data-services](https://github.com/karthik-ak-dev/terraform-aws-data-services) | Aurora, DynamoDB, Redis, OpenSearch, S3 |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    terraform-aws-infrastructure                             │
│                         (This Repository)                                   │
│                                                                             │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│   │  environments/  │  │  environments/  │  │  environments/  │             │
│   │      dev/       │  │     stage/      │  │      prod/      │             │
│   └────────┬────────┘  └────────┬────────┘  └────────┬────────┘             │
│            │                    │                    │                      │
│            └────────────────────┼────────────────────┘                      │
│                                 │                                           │
│                                 ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                     Module Sources (Git)                            │   │
│   │                                                                     │   │
│   │  ┌───────────────────┐ ┌───────────────────┐ ┌───────────────────┐  │   │
│   │  │ terraform-aws-    │ │ terraform-aws-    │ │ terraform-aws-    │  │   │
│   │  │ organization      │ │ eks-platform      │ │ data-services     │  │   │
│   │  │ ?ref=v1.0.0       │ │ ?ref=v1.0.0       │ │ ?ref=v1.0.0       │  │   │
│   │  └───────────────────┘ └───────────────────┘ └───────────────────┘  │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
.
├── environments/
│   ├── dev/
│   │   ├── main.tf                 # Dev infrastructure
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   ├── stage/
│   │   └── ...
│   └── prod/
│       ├── main.tf                 # Production infrastructure
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
├── docs/
│   └── architecture.md
├── README.md
├── LICENSE
└── .gitignore
```

## How Modules Are Referenced

Each environment pulls modules from Git with version pinning:

```hcl
# VPC from eks-platform repo
module "vpc" {
  source = "git::https://github.com/karthik-ak-dev/terraform-aws-eks-platform.git//terraform/modules/vpc?ref=v1.0.0"
  # ...
}

# Database from data-services repo
module "aurora" {
  source = "git::https://github.com/karthik-ak-dev/terraform-aws-data-services.git//modules/aurora-postgres?ref=v1.0.0"
  # ...
}
```

## Environment Differences

| Aspect | Dev | Prod |
|--------|-----|------|
| NAT Gateway | Single (cost savings) | Multi-AZ (HA) |
| EKS Nodes | 2x t3.medium | 3x t3.large + Spot pool |
| Database | Aurora Serverless (0.5-4 ACU) | Aurora Provisioned (2x r6g.large) |
| Cache | Valkey Serverless | Redis Multi-AZ |
| VPC Flow Logs | Disabled | Enabled |
| AZs | 2 | 3 |

## Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/karthik-ak-dev/terraform-aws-infrastructure.git
cd terraform-aws-infrastructure/environments/dev

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Deploy Dev Environment

```bash
terraform init
terraform plan
terraform apply
```

### 3. Configure kubectl

```bash
# Output will show the command:
aws eks update-kubeconfig --region us-east-1 --name myproject-eks-cluster
```

## Module Version Management

### Updating Module Versions

To update a module version:

1. Check the module repo for new releases
2. Update the `?ref=` parameter in main.tf
3. Run `terraform init -upgrade`
4. Review changes with `terraform plan`
5. Apply changes

```hcl
# Before
source = "git::https://github.com/karthik-ak-dev/terraform-aws-eks-platform.git//terraform/modules/vpc?ref=v1.0.0"

# After
source = "git::https://github.com/karthik-ak-dev/terraform-aws-eks-platform.git//terraform/modules/vpc?ref=v1.1.0"
```

### Version Strategy

| Environment | Strategy |
|-------------|----------|
| Dev | Can use `?ref=main` for testing |
| Stage | Use release candidates `?ref=v1.1.0-rc1` |
| Prod | Always pin to stable releases `?ref=v1.0.0` |

## State Management

Each environment should have its own state file. Recommended: Use S3 backend with DynamoDB locking.

```hcl
terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state"
    key            = "dev/terraform.tfstate"  # Different per environment
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |
| helm | ~> 2.0 |

## Related Repositories

- [terraform-aws-organization](https://github.com/karthik-ak-dev/terraform-aws-organization) - AWS Organizations & IAM Identity Center
- [terraform-aws-eks-platform](https://github.com/karthik-ak-dev/terraform-aws-eks-platform) - EKS, VPC, ALB, ECR, CI/CD
- [terraform-aws-data-services](https://github.com/karthik-ak-dev/terraform-aws-data-services) - Databases, caching, storage

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

**Karthik**

*AWS Platform Engineer specializing in infrastructure automation, Kubernetes, and cloud-native architectures.*
