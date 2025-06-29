variable "aws_region" {
  description = "デプロイ先の AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_account_id" {
  description = "リソースARNに使うアカウントID"
  type        = string
  default     = "676206918971"
}

variable "env" { default = "dev" }
variable "ec2_key" {
  description = "Name of the EC2 key pair to use for the EKS nodes"
  type        = string
}
