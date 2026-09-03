resource "helm_release" "kong" {
  name             = "kong"
  repository       = "https://charts.konghq.com"
  chart            = "kong"
  version          = var.kong_chart_version
  namespace        = "kong"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      proxy = {
        type = "LoadBalancer"
        http = {
          enabled     = true
          servicePort = 80
        }
        tls = {
          enabled = false
        }
      }
      ingressController = {
        enabled = true
      }
      admin = {
        enabled = false
      }
    })
  ]

  depends_on = [aws_eks_node_group.oficina_nodes]
}

resource "kubernetes_config_map_v1" "kong_auth_target" {
  metadata {
    name      = "kong-auth-target"
    namespace = "kong"
  }

  data = {
    auth_lambda_function_name = var.auth_lambda_function_name
    aws_region                = var.aws_region
  }

  depends_on = [helm_release.kong]
}
