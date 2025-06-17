output "cluster_name" { value = module.eks.cluster_name }
output "model_bucket" { value = aws_s3_bucket.model_store.bucket }
output "vpc_id" {
  value = module.vpc.vpc_id
}
output "private_subnets" {
  value = module.vpc.private_subnets
}