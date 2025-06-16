variable "aws_region" { default = "us-west-2" }
variable "env"        { default = "dev" }
variable "vpc_id"     { }
variable "subnets"    { type = list(string) }
variable "ec2_key"    { }