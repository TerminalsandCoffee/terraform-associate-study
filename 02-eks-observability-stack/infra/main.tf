terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    Project   = "eks-observability-demo"
    ManagedBy = "Terraform"
  }

  otel_service_account = {
    namespace = "observability"
    name      = "otel-collector"
  }
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for idx, az in local.azs : cidrsubnet(var.vpc_cidr, 4, idx)]
  public_subnets  = [for idx, az in local.azs : cidrsubnet(var.vpc_cidr, 4, idx + 8)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true
  enable_irsa                    = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      desired_size   = var.node_desired_capacity
      max_size       = var.node_max_size
      min_size       = var.node_min_size
      capacity_type  = "SPOT"

      tags = {
        "k8s.io/cluster-autoscaler/enabled"                 = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}"     = "owned"
        "eks.amazonaws.com/capacityType"                    = "SPOT"
      }
    }
  }

  tags = local.tags
}

resource "aws_iam_policy" "otel_collector" {
  name        = "${var.cluster_name}-otel"
  description = "Minimal permissions for the OpenTelemetry collector to publish metrics and logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      }
    ]
  })
}

data "aws_iam_policy_document" "otel_irsa" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values = [
        "system:serviceaccount:${local.otel_service_account.namespace}:${local.otel_service_account.name}"
      ]
    }
  }
}

resource "aws_iam_role" "otel_irsa" {
  name               = "${var.cluster_name}-otel-irsa"
  assume_role_policy = data.aws_iam_policy_document.otel_irsa.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "otel_irsa" {
  role       = aws_iam_role.otel_irsa.name
  policy_arn = aws_iam_policy.otel_collector.arn
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "otel_irsa_role_arn" {
  description = "IAM role bound to the OpenTelemetry collector service account"
  value       = aws_iam_role.otel_irsa.arn
}
