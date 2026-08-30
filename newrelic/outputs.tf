output "alert_policy_id" {
  description = "ID da policy de alerta de falha no processamento de OS"
  value       = newrelic_alert_policy.falha_processamento_os.id
}
