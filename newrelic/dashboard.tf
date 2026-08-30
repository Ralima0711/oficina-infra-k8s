# Dashboard de Ordens de Servico (OS) - volume, tempo medio por status e erros

resource "newrelic_one_dashboard" "ordens_servico" {
  name        = "Oficina Mecanica - Ordens de Servico"
  permissions = "public_read_only"

  page {
    name = "Visao geral"

    widget_billboard {
      title  = "OS criadas (24h)"
      row    = 1
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM Transaction WHERE appName = '${var.newrelic_apm_app_name}' AND request.uri LIKE '%/ordens-servico' AND request.method = 'POST' SINCE 1 day ago"
      }
    }

    widget_line {
      title  = "Volume de requisicoes de OS por rota"
      row    = 1
      column = 5
      width  = 8
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM Transaction WHERE appName = '${var.newrelic_apm_app_name}' AND request.uri LIKE '%/ordens-servico%' FACET request.uri TIMESERIES AUTO"
      }
    }

    widget_line {
      title  = "Erros de transacao no fluxo de OS"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM TransactionError WHERE appName = '${var.newrelic_apm_app_name}' AND request.uri LIKE '%/ordens-servico%' TIMESERIES AUTO"
      }
    }

    widget_billboard {
      title  = "Falhas de processamento de OS (logs)"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT count(*) FROM Log WHERE message LIKE '%Falha ao enviar notifica%' OR message LIKE '%Falha ao persistir notifica%' SINCE 1 day ago"
      }
    }

    widget_bar {
      title  = "Tempo medio de execucao por status (min) - Diagnostico, Execucao, Finalizacao"
      row    = 7
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "SELECT average(tempo_medio_minutos) FROM OrdemServicoTempoMedioSample FACET status SINCE 1 hour ago"
      }
    }
  }
}

output "dashboard_guid" {
  description = "GUID do dashboard de Ordens de Servico"
  value       = newrelic_one_dashboard.ordens_servico.guid
}
