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

variable "newrelic_license_key" {
  description = "License key (INGEST - LICENSE) da conta New Relic, usada pelo bundle de infraestrutura/logging instalado no cluster (newrelic-k8s.tf). Vazio = bundle nao e instalado. Vem de secret do CI/CD — nunca versionar."
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_host" {
  description = "Host do RDS PostgreSQL (output db_address do repo oficina-infra-database), usado pelo nri-postgresql para o painel de tempo medio de execucao de OS por status. Vazio = integracao nao e criada."
  type        = string
  default     = ""
}

variable "db_username" {
  description = "Usuario do RDS PostgreSQL usado pelo nri-postgresql"
  type        = string
  default     = ""
}

variable "db_password" {
  description = "Senha do RDS PostgreSQL usada pelo nri-postgresql"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_name" {
  description = "Nome do banco PostgreSQL"
  type        = string
  default     = "oficina_mecanica"
}
