output "alert_policy_id" {
  description = "ID da policy de alerta de falha no processamento de OS"
  value       = newrelic_alert_policy.falha_processamento_os.id
}

output "uptime_monitor_id" {
  description = "Monitor de uptime do /api/health (vazio quando health_check_url nao foi informada)"
  value       = try(newrelic_synthetics_monitor.api_health[0].id, "")
}
