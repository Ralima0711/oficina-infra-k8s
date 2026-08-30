# oficina-infra-k8s

Infraestrutura como código do cluster **Kubernetes (AWS EKS)** e do **API Gateway Kong** do Tech Challenge SOAT — Fase 3 (Grupo 183).

> Repositório 2 de 4 da Fase 3. Ver também: [oficina-mecanica-api](https://github.com/Ralima0711/oficina-mecanica-api) · [oficina-lambda-auth](https://github.com/Ralima0711/oficina-lambda-auth) · [oficina-infra-database](https://github.com/Ralima0711/oficina-infra-database)

## Propósito

Provisionar, de forma reprodutível, o cluster EKS que executa a aplicação e o API Gateway **Kong** (no próprio cluster) que roteia e protege as rotas. Isolado do banco (repo `oficina-infra-database`) e da aplicação para permitir CI/CD independente.

Este stack (EKS) foi extraído do monorepo da API. O Kong é novo na Fase 3 (contrato de autenticação rev.3).

## Tecnologias

| Tecnologia | Papel |
|---|---|
| Terraform (≥ 1.3) | Provisionamento da infraestrutura AWS e instalação do Kong (Helm) |
| AWS EKS | Cluster Kubernetes gerenciado |
| Kong (Ingress Controller no EKS) | Roteamento e proteção das rotas (`/auth`, `/api`, `/api/public`) |
| Kubernetes HPA | Escalabilidade da API (manifestos no repo da aplicação: min 2 / max 10 pods) |
| GitHub Actions | Pipeline CI/CD (`terraform plan` no PR → `apply` + `kubectl` em `homolog`/`main`) |

## Recursos provisionados

| Recurso | Detalhe |
|---|---|
| `aws_eks_cluster` | Cluster Kubernetes gerenciado |
| `aws_eks_node_group` | Node group t3.medium (1–4 nós, desired 2) |
| Helm `kong/kong` | Proxy LoadBalancer + Ingress Controller |
| Ingress `/auth` | Público → plugin `aws-lambda` (quando a function existir) |
| Ingress `/api` | API Laravel (staff continua validando JWT HS256 na aplicação) |
| Ingress `/api/public` | Rotas de cliente: Kong exige `Authorization: Bearer` |
| Helm `newrelic/nri-bundle` | Agente de infra + logging + kube-state-metrics do New Relic (namespace `newrelic`); só instala se `newrelic_license_key` estiver preenchida |
| `nri-postgresql` (integração no bundle) | Query customizada no RDS para o painel de tempo médio de OS por status; só é criada se `db_host`/`db_username`/`db_password` estiverem preenchidos |

O HPA da API permanece em `oficina-mecanica-api/k8s/hpa.yaml`.

## Execução / Deploy

```bash
cp terraform.tfvars.example terraform.tfvars
# AWS Academy: LabRole ARN + subnet IDs da VPC do laboratório

terraform init
terraform plan -out=tfplan
terraform apply tfplan

aws eks update-kubeconfig --region us-east-1 --name oficina-mecanica-cluster
kubectl apply -f k8s/dummy-auth-service.yaml
kubectl apply -f k8s/plugin-require-bearer.yaml
kubectl apply -f k8s/ingress-api.yaml
kubectl apply -f k8s/ingress-api-public.yaml
# Depois da Lambda:
# sed "s/AUTH_LAMBDA_FUNCTION_NAME/<nome-da-function>/" k8s/plugin-aws-lambda.yaml | kubectl apply -f -
# kubectl apply -f k8s/ingress-auth.yaml
```

O deploy é automatizado via GitHub Actions nas branches `homolog` e `main`.

Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `TF_VAR_LAB_ROLE_ARN`, `TF_VAR_SUBNET_IDS`, opcional `AUTH_LAMBDA_FUNCTION_NAME`, opcional `NEWRELIC_LICENSE_KEY` (bundle de infra/logging do New Relic — enquanto vazio, esse Helm release simplesmente não é criado), opcionais `TF_VAR_DB_HOST`/`TF_VAR_DB_USERNAME`/`TF_VAR_DB_PASSWORD` (outputs do repo `oficina-infra-database` — enquanto vazios, a integração `nri-postgresql` não é criada).

## Diagrama

```
Cliente/Staff
      │
      ▼
Kong (LoadBalancer no EKS)
      ├── POST /auth              → Lambda (pública)
      ├── GET  /api/health        → API (pública)
      ├── /api/public/*           → API (Bearer obrigatório no Kong)
      └── /api/*                  → API (staff: JWT na Laravel)
      │
      ▼
EKS (pods da API + HPA) ──▶ RDS (repo oficina-infra-database)
```

## Monitoramento (New Relic)

A integração com o New Relic tem duas partes com ciclos de vida diferentes — ver
[Reaplicando após o AWS Academy expirar](#reaplicando-após-o-aws-academy-expirar) antes de
testar.

### 1. Bundle no cluster (`newrelic-k8s.tf`, raiz deste repo)

Instala via Helm (`nri-bundle`) o agente de infraestrutura, logging e
`kube-state-metrics` no cluster, e opcionalmente a integração `nri-postgresql`
(query customizada no RDS para o painel de tempo médio de OS por status,
reaproveitando a mesma lógica de
`EloquentOrdemServicoRepository::tempoMedioExecucao()`, facetada pelos 3 status do
desafio: `EM_DIAGNOSTICO`, `EM_EXECUCAO`, `FINALIZADA`). Faz parte do `terraform apply`
principal (raiz) — ver variáveis `newrelic_license_key` e `db_host`/`db_username`/`db_password`
no `terraform.tfvars`.

### 2. Alertas e dashboard (diretório `newrelic/`)

Módulo Terraform independente (state e pipeline próprios,
`.github/workflows/newrelic-alerts.yml`, só roda quando arquivos dessa pasta mudam) que cria
no New Relic:

- policy + condição NRQL que dispara quando aparecem logs de falha no processamento de OS
  (`Falha ao enviar notificação de status da OS` / `Falha ao persistir notificação de sistema
  da OS`, emitidos por `OrdemServicoService` na API);
- canal de notificação por e-mail (`alert_email` no `terraform.tfvars` do módulo — é o
  único uso dessa variável, vira a `property { key = "email" }` do
  `newrelic_notification_destination`);
- dashboard "Ordens de Serviço" com volume diário de OS, tempo médio de execução por
  status (Diagnóstico/Execução/Finalização) e erros/falhas nas integrações.

Pré-requisito: conta New Relic (free tier em [newrelic.com/signup](https://newrelic.com/signup))
com a aplicação enviando logs (agente PHP / integração Kubernetes — tarefa "Configurar New
Relic"). Sem isso a condição NRQL nunca vai encontrar dados.

```bash
cd newrelic
cp terraform.tfvars.example terraform.tfvars
# preencher newrelic_account_id e alert_email; newrelic_api_key vem de variável de ambiente
# (TF_VAR_newrelic_api_key) ou de secret do CI — nunca committar a API key

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Secrets do CI (Settings → Secrets → Actions): `NEWRELIC_API_KEY`, `NEWRELIC_ACCOUNT_ID`,
`NEWRELIC_ALERT_EMAIL`. Enquanto não forem cadastrados, o workflow roda `plan`/`apply` em modo
"skip" (mesmo padrão do `terraform-plan/apply` principal sem credenciais AWS).

### Reaplicando após o AWS Academy expirar

O laboratório do AWS Academy é temporário — quando a sessão cai, o cluster EKS e o RDS
somem (ou as credenciais expiram e é preciso recriar tudo). Nem tudo precisa ser refeito:

| Camada | Onde o recurso vive | Reaplicar quando o lab cai? |
|---|---|---|
| `newrelic/` (policy, condição, canal, dashboard) | Conta New Relic, fora da AWS | **Não.** Aplicado uma vez, fica lá. Só reaplica se mudar a definição do alerta/dashboard. |
| `newrelic-k8s.tf` (bundle Helm + `nri-postgresql`) | Dentro do cluster EKS | **Sim** — é um `helm_release`, some junto com o cluster. Reinstalado automaticamente no próximo `terraform apply` da raiz. |
| RDS (`oficina-infra-database`) | AWS Academy | **Sim.** E o endpoint (`db_host`) muda se o RDS for recriado — atualizar no `terraform.tfvars` da raiz antes de reaplicar. |
| EKS + Kong (raiz deste repo) | AWS Academy | **Sim**, mesma lógica. |

Ordem pra retomar o trabalho depois de um reset do lab:

1. Pegar credenciais novas do AWS Academy (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN`)
   e a account ID nova (`aws sts get-caller-identity`) — conferir se `lab_role_arn` no
   `terraform.tfvars` bate com ela.
2. `terraform apply` em `oficina-infra-database` → anotar o novo `db_address` (output).
3. Atualizar `db_host` no `terraform.tfvars` da raiz deste repo com o endpoint novo.
4. `terraform apply` na raiz — recria EKS + Kong + reinstala o bundle do New Relic
   (com `nri-postgresql` já apontando pro RDS novo).
5. **Não** precisa reaplicar `newrelic/` — os alertas e o dashboard continuam intactos na
   conta New Relic.

## Regras de contribuição

Branch `main` protegida. Todo merge via **Pull Request** com aprovação de outro membro. Nunca commitar `terraform.tfvars` nem state com segredos.

## Time — Grupo 183

Roberta Lima (Tech Lead) · Gustavo Delfino (Infra/CI-CD) · David Tavares (Infra/CI-CD) · Johny David (Aplicação)
