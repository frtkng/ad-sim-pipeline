##############################
# Amazon ECR – CARLA 用
##############################
resource "aws_ecr_repository" "carla" {
  name                 = "e2e-ai-carla-${var.env}" # <- リポジトリ名
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true # 脆弱性スキャンを自動実行
  }

  encryption_configuration {
    encryption_type = "AES256" # デフォルト暗号化
  }

  tags = {
    Project = "E2E AI CICT"
  }
}

##############################
# 出力（後で GitHub Actions などで使う）
##############################
output "ecr_carla_url" {
  description = "CARLA image repository"
  value       = aws_ecr_repository.carla.repository_url
}