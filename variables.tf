variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
  default     = "oficina-mecanica-cluster"
}

variable "lab_role_arn" {
  description = "ARN da role do AWS Academy Lab (cluster e nodes)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets da VPC do laboratório para o EKS"
  type        = list(string)
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "kong_chart_version" {
  description = "Versão do chart Helm kong/kong"
  type        = string
  default     = "2.46.0"
}

variable "auth_lambda_function_name" {
  description = "Nome da function SAM de autenticação (plugin aws-lambda no Kong). Vazio = rota /auth ainda não invoca a Lambda."
  type        = string
  default     = ""
}
