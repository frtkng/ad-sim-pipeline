variable "aws_region" { default = "ap-northeast-1" }
variable "env"        { default = "dev" }
variable "ec2_key" {
  description = "Name of the EC2 key pair to use for the EKS nodes"
  type        = string
}