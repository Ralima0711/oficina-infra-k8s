
# Integracao nri-postgresql: alimenta o painel "tempo medio de execucao por
# status" do dashboard (newrelic/dashboard.tf) rodando uma query
# customizada direto no RDS - media de (updated_at - created_at) por status,
# reaproveitando a mesma logica de EloquentOrdemServicoRepository::tempoMedioExecucao().
# Vazio (db_host/db_username/db_password) = integracao nao e criada.
locals {
  newrelic_postgresql_enabled = var.db_host != "" && var.db_username != "" && var.db_password != ""

  newrelic_postgresql_values = {
    "newrelic-infrastructure" = {
      integrations = {
        "nri-postgresql-config.yaml" = {
          integrations = [
            {
              name = "nri-postgresql"
              env = {
                HOSTNAME                 = var.db_host
                PORT                     = "5432"
                USERNAME                 = var.db_username
                PASSWORD                 = var.db_password
                DATABASE                 = var.db_name
                ENABLE_SSL               = "true"
                TRUST_SERVER_CERTIFICATE = "true"
                CUSTOM_METRICS_CONFIG    = "/etc/newrelic-infra/integrations.d/oficina-os-tempo-medio-query.yaml"
              }
              interval = "60s"
              labels = {
                env = "oficina-mecanica"
              }
            }
          ]
        }
        "oficina-os-tempo-medio-query.yaml" = {
          queries = [
            {
              query       = <<-SQL
                SELECT status AS "status",
                       ROUND(AVG(EXTRACT(EPOCH FROM (updated_at - created_at)) / 60)::numeric, 2) AS "tempo_medio_minutos"
                FROM ordens_servico
                WHERE status IN ('EM_DIAGNOSTICO', 'EM_EXECUCAO', 'FINALIZADA')
                GROUP BY status
              SQL
              database    = var.db_name
              sample_name = "OrdemServicoTempoMedioSample"
              metric_types = {
                tempo_medio_minutos = "gauge"
              }
            }
          ]
        }
      }
    }
  }
}

resource "helm_release" "newrelic_bundle" {
  count = var.newrelic_license_key != "" ? 1 : 0

  name             = "newrelic-bundle"
  repository       = "https://helm-charts.newrelic.com"
  chart            = "nri-bundle"
  namespace        = "newrelic"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = concat(
    [
      yamlencode({
        global = {
          cluster     = aws_eks_cluster.oficina.name
          licenseKey  = var.newrelic_license_key
          lowDataMode = true
          privileged  = true
          fargate     = false
        }

        "newrelic-infrastructure"      = { enabled = true }
        "nri-prometheus"               = { enabled = false }
        "nri-metadata-injection"       = { enabled = true }
        "kube-state-metrics"           = { enabled = true }
        "nri-kube-events"              = { enabled = true }
        "newrelic-logging"             = { enabled = true }
        "newrelic-pixie"               = { enabled = false }
        "pixie-chart"                  = { enabled = false }
        "newrelic-infra-operator"      = { enabled = false }
        "newrelic-prometheus-agent"    = { enabled = true }
        "nr-ebpf-agent"                = { enabled = true }
        "k8s-agents-operator"          = { enabled = true }
        "newrelic-k8s-metrics-adapter" = { enabled = false }
      })
    ],
    local.newrelic_postgresql_enabled ? [yamlencode(local.newrelic_postgresql_values)] : []
  )

  depends_on = [aws_eks_node_group.oficina_nodes]
}
