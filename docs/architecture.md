# Architecture Overview

This document describes the complete AWS infrastructure architecture deployed by this repository.

## High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                                AWS Cloud                                           │
│                                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │                              VPC (10.0.0.0/16)                               │  │
│  │                                                                              │  │
│  │   ┌─────────────────────────────┐    ┌─────────────────────────────┐         │  │
│  │   │      Public Subnets         │    │      Private Subnets        │         │  │
│  │   │                             │    │                             │         │  │
│  │   │  ┌───────────────────────┐  │    │  ┌───────────────────────┐  │         │  │
│  │   │  │   Application Load    │  │    │  │    EKS Node Group     │  │         │  │
│  │   │  │      Balancer         │◄─┼────┼──│                       │  │         │  │
│  │   │  └───────────────────────┘  │    │  │  ┌─────┐  ┌─────┐     │  │         │  │
│  │   │                             │    │  │  │ Pod │  │ Pod │     │  │         │  │
│  │   │  ┌───────────────────────┐  │    │  │  └──┬──┘  └──┬──┘     │  │         │  │
│  │   │  │     NAT Gateway       │──┼────┼──│     │        │        │  │         │  │
│  │   │  └───────────────────────┘  │    │  └─────┼────────┼───────-┘  │         │  │
│  │   │                             │    │        │        │           │         │  │
│  │   └─────────────────────────────┘    │        ▼        ▼           │         │  │
│  │                                      │  ┌───────────────────────┐  │         │  │
│  │                                      │  │   Aurora PostgreSQL   │  │         │  │
│  │                                      │  │   (Multi-AZ)          │  │         │  │
│  │                                      │  └───────────────────────┘  │         │  │
│  │                                      │                             │         │  │
│  │                                      │  ┌───────────────────────┐  │         │  │
│  │                                      │  │   ElastiCache Redis   │  │         │  │
│  │                                      │  │   (Multi-AZ)          │  │         │  │
│  │                                      │  └───────────────────────┘  │         │  │
│  │                                      └────────────────────────────-┘         │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                    │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐         │
│  │        ECR          │  │    IAM (OIDC)       │  │     CloudWatch      │         │
│  │  Container Registry │  │  GitHub Actions     │  │   Logs & Metrics    │         │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘         │
└────────────────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### Networking (VPC)

| Component | Dev | Prod |
|-----------|-----|------|
| Availability Zones | 2 | 3 |
| Public Subnets | 2 | 3 |
| Private Subnets | 2 | 3 |
| NAT Gateway | 1 (shared) | 3 (per AZ) |
| VPC Flow Logs | Disabled | Enabled |

### Compute (EKS)

| Component | Dev | Prod |
|-----------|-----|------|
| Kubernetes Version | 1.29 | 1.29 |
| Node Groups | 1 (On-Demand) | 2 (On-Demand + Spot) |
| Node Instance Type | t3.medium | t3.large/xlarge |
| Min/Max Nodes | 1-4 | 2-30 |
| Fargate | Optional | Optional |

### Database (Aurora PostgreSQL)

| Component | Dev | Prod |
|-----------|-----|------|
| Engine | Aurora Serverless v2 | Aurora Provisioned |
| Instance Class | N/A (0.5-4 ACU) | db.r6g.large |
| Instances | 1 | 2 (Writer + Reader) |
| Multi-AZ | No | Yes |
| Encryption | Yes | Yes |

### Caching

| Component | Dev | Prod |
|-----------|-----|------|
| Service | Valkey Serverless | ElastiCache Redis |
| Node Type | Serverless | cache.r6g.large |
| Nodes | Auto-scaled | 2 (Multi-AZ) |
| Auth | Yes | Yes (AUTH token) |

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Security Layers                             │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Layer 1: Network Security                                 │  │
│  │  • VPC isolation                                          │  │
│  │  • Private subnets for workloads                          │  │
│  │  • Security groups (least privilege)                      │  │
│  │  • NACLs for subnet-level control                         │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Layer 2: Identity & Access                                │  │
│  │  • IRSA (IAM Roles for Service Accounts)                  │  │
│  │  • No static credentials in pods                          │  │
│  │  • GitHub OIDC for CI/CD (no long-lived keys)             │  │
│  │  • Kubernetes RBAC                                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Layer 3: Data Protection                                  │  │
│  │  • Encryption at rest (KMS)                               │  │
│  │  • Encryption in transit (TLS)                            │  │
│  │  • Secrets in AWS Secrets Manager                         │  │
│  │  • ECR image scanning                                     │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## CI/CD Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Developer  │────►│    GitHub    │────►│  GitHub      │────►│     ECR      │
│   Push Code  │     │   Actions    │     │  OIDC Auth   │     │  Push Image  │
└──────────────┘     └──────────────┘     └──────────────┘     └──────┬───────┘
                                                                      │
                                                                      ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Service    │◄────│     EKS      │◄────│    Helm      │◄────│   Deploy     │
│   Running    │     │   Cluster    │     │   Release    │     │   Workflow   │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

## Cost Optimization Strategy

### Dev Environment
- Single NAT Gateway (~$32/month saved per extra NAT)
- Serverless databases (pay per use)
- Smaller instance types
- No VPC Flow Logs

### Production Environment
- Reserved Instances for predictable workloads
- Spot Instances for fault-tolerant batch jobs
- Right-sized instances based on metrics
- S3 lifecycle policies for logs

## Disaster Recovery

| Aspect | Strategy |
|--------|----------|
| Database | Automated backups, point-in-time recovery |
| EKS | Multi-AZ node groups, pod disruption budgets |
| State | S3 versioning for Terraform state |
| Secrets | AWS Secrets Manager with rotation |

## Monitoring & Observability

| Component | Tool |
|-----------|------|
| Metrics | CloudWatch Container Insights |
| Logs | CloudWatch Logs |
| Tracing | AWS X-Ray (optional) |
| Alerting | CloudWatch Alarms → SNS |
