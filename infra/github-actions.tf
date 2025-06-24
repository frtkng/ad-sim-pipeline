# 1. 既存の GitHub OIDC プロバイダーを参照
data "aws_iam_openid_connect_provider" "github" {
  # すでに作成済みのプロバイダー ARN をここに指定
  arn = "arn:aws:iam::676206918971:oidc-provider/token.actions.githubusercontent.com"
}

# 2. GitHub Actions 用 IAM ロール
resource "aws_iam_role" "github_actions" {
  name = "github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # main ブランチの Actions 実行時のみ許可
          "token.actions.githubusercontent.com:sub" = "repo:frtkng/e2e-ai-cict-mockup:ref:refs/heads/master"
        }
      }
    }]
  })
}

# 3. マネージドポリシーのアタッチ
locals {
  ci_managed_policies = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
  ]
}

resource "aws_iam_role_policy_attachment" "github_actions_managed" {
  for_each   = toset(local.ci_managed_policies)
  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}

# 4. EC2 キーペア操作を許可するインラインポリシー
data "aws_iam_policy_document" "ci_ec2_keypair" {
  statement {
    sid     = "AllowCreateAndDeleteKeyPair"
    effect  = "Allow"
    actions = [
      "ec2:CreateKeyPair",
      "ec2:DeleteKeyPair",
      "ec2:DescribeKeyPairs",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ci_ec2_keypair" {
  name   = "ci-ec2-keypair-policy"
  role   = aws_iam_role.github_actions.name
  policy = data.aws_iam_policy_document.ci_ec2_keypair.json
}

# ──────────── Terraform Lock 用 DynamoDB 操作権限 ────────────
data "aws_iam_policy_document" "ci_dynamodb_lock" {
  statement {
    sid     = "AllowDynamoDBLockTableAccess"
    effect  = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/terraform-locks",
    ]
  }
}

resource "aws_iam_role_policy" "ci_dynamodb_lock" {
  name   = "ci-dynamodb-lock-policy"
  role   = aws_iam_role.github_actions.name
  policy = data.aws_iam_policy_document.ci_dynamodb_lock.json
}

// 5) Terraform data/read permissions for EKS/VPC modules (expanded)

data "aws_iam_policy_document" "ci_terraform_read" {
  statement {
    sid     = "AllowTerraformDataReads"
    effect  = "Allow"
    actions = [
      # IAM / OIDC
      "iam:GetOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders",
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",

      # EKS
      "eks:DescribeCluster",

      # EC2 / VPC
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeRouteTables",
      "ec2:DescribeNetworkAcls",
      "ec2:DescribeAddresses",
      "ec2:DescribeAddressesAttribute",
      "ec2:DescribeNatGateways",

      # CloudWatch Logs
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
      "logs:CreateLogGroup",

      # KMS
      "kms:GetKeyPolicy",
      "kms:DescribeKey",
      "kms:ListKeys",
      "kms:ListAliases",
      "kms:GetKeyRotationStatus"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ci_terraform_read" {
  name   = "ci-terraform-read-policy"
  role   = aws_iam_role.github_actions.name
  policy = data.aws_iam_policy_document.ci_terraform_read.json
}