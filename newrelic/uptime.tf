# Monitor de uptime do healthcheck da API.
# Atende ao requisito "Healthchecks e uptime" do Tech Challenge: o /api/health
# ja e usado pelas probes do Kubernetes; aqui ele vira serie historica de
# disponibilidade e tempo de resposta no New Relic.
#
# Fica desativado enquanto health_check_url estiver vazio -- util porque o
# ambiente do lab e efemero e a URL muda a cada janela (ver ADR-0006).

resource "newrelic_synthetics_monitor" "api_health" {
  count = var.health_check_url == "" ? 0 : 1

  name              = "oficina-mecanica-api - health"
  type              = "SIMPLE"
  uri               = var.health_check_url
  period            = "EVERY_5_MINUTES"
  status            = "ENABLED"
  locations_public  = ["US_EAST_1"]
  validation_string = "ok"
  verify_ssl        = true

  tag {
    key    = "Project"
    values = ["oficina-mecanica"]
  }
}
