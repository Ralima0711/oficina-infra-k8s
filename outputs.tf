output "cluster_endpoint" {
  description = "Endpoint da API do EKS"
  value       = aws_eks_cluster.oficina.endpoint
}

output "cluster_name" {
  description = "Nome do cluster"
  value       = aws_eks_cluster.oficina.name
}

output "cluster_arn" {
  description = "ARN do cluster"
  value       = aws_eks_cluster.oficina.arn
}

output "kong_namespace" {
  description = "Namespace do Kong"
  value       = helm_release.kong.namespace
}

output "configure_kubectl" {
  description = "Comando para apontar o kubectl para este cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.oficina.name}"
}
