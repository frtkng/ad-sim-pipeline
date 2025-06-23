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
