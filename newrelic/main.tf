

resource "newrelic_notification_destination" "alertas_os_email" {
  name = "oficina-mecanica-alertas-os-email"
  type = "EMAIL"

  property {
    key   = "email"
    value = var.alert_email
  }
}

resource "newrelic_notification_channel" "alertas_os_email" {
  name           = "oficina-mecanica-alertas-os-email"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.alertas_os_email.id
  product        = "IINT"

  property {
    key   = "subject"
    value = "[oficina-mecanica] Falha no processamento de OS"
  }
}

resource "newrelic_alert_policy" "falha_processamento_os" {
  name                = "oficina-mecanica-falha-processamento-os"
  incident_preference = "PER_CONDITION"
}

resource "newrelic_nrql_alert_condition" "falha_processamento_os" {
  policy_id                    = newrelic_alert_policy.falha_processamento_os.id
  name                         = "Falha ao processar OS (log de erro da aplicacao)"
  enabled                      = true
  violation_time_limit_seconds = 3600
  aggregation_window           = 300
  aggregation_method           = "event_flow"
  aggregation_delay            = 120

  nrql {
    query = "SELECT count(*) FROM Log WHERE message LIKE '%Falha ao enviar notifica%' OR message LIKE '%Falha ao persistir notifica%'"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }
}

resource "newrelic_workflow" "falha_processamento_os" {
  name                  = "oficina-mecanica-falha-processamento-os"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "filter-falha-processamento-os"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.falha_processamento_os.id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.alertas_os_email.id
  }
}
