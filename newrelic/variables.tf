variable "newrelic_account_id" {
  description = "Account ID da conta New Relic (New Relic One > perfil > API keys)"
  type        = number
}

variable "newrelic_api_key" {
  description = "User API Key da conta New Relic, usada pelo Terraform para criar policy/condicao/canal de alerta"
  type        = string
  sensitive   = true
}

variable "newrelic_region" {
  description = "Regiao da conta New Relic (US ou EU)"
  type        = string
  default     = "US"
}

variable "alert_email" {
  description = "E-mail que recebe o alerta de falha no processamento de OS"
  type        = string
}

variable "newrelic_apm_app_name" {
  description = "Nome do app APM configurado no agente PHP (newrelic.appname), usado nas queries do dashboard"
  type        = string
  default     = "oficina-mecanica-api"
}
