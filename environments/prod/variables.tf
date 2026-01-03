# ============================================================================
# PRODUCTION ENVIRONMENT VARIABLES
# ============================================================================

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "db_password" {
  description = "Master password for Aurora database"
  type        = string
  sensitive   = true
}

variable "redis_auth_token" {
  description = "Auth token for Redis"
  type        = string
  sensitive   = true
}

variable "github_oidc_provider_arn" {
  description = "ARN of existing GitHub OIDC provider"
  type        = string
}

variable "application_roles" {
  description = "Application IAM roles for IRSA"
  type = map(object({
    namespace       = string
    service_account = string
    policy_arns     = list(string)
  }))
  default = {}
}

variable "github_repositories" {
  description = "GitHub repositories allowed to assume the CI/CD role"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
