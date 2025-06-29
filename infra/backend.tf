terraform {
  backend "s3" {
    bucket         = "beans-terraform-state-bucket"  # state 用バケット
    key            = "e2e-ai-cict/terraform.tfstate" # state ファイルのパス
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-locks" # ロック用テーブル
    encrypt        = true
  }
}