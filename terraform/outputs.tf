output "cluster_name" { value = module.eks.cluster_name }
output "kubeconfig" { value = module.eks.kubeconfig }
output "model_bucket" { value = aws_s3_bucket.model_store.bucket }