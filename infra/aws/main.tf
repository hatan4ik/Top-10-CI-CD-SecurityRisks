terraform {
  required_version = ">= 1.5.0"
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

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "github_org" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "ecr_repo_name" {
  type    = string
  default = "ci-cd-zero-to-hero"
}

# ECR repository
resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "IMMUTABLE"
}

# GitHub OIDC provider (if not already created at org/account level)
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "ffffffffffffffffffffffffffffffffffffffff"
  ]
}

# IAM role for GitHub Actions deployments
resource "aws_iam_role" "gh_actions_ci_prod" {
  name = "gh-actions-ci-prod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "gh_actions_ci_prod_policy" {
  role = aws_iam_role.gh_actions_ci_prod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage"
        ]
        Resource = [
          aws_ecr_repository.app.arn
        ]
      }
    ]
  })
}
