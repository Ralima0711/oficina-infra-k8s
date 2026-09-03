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

Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `TF_VAR_LAB_ROLE_ARN`, `TF_VAR_SUBNET_IDS`, opcional `AUTH_LAMBDA_FUNCTION_NAME`.

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

## Regras de contribuição

Branch `main` protegida. Todo merge via **Pull Request** com aprovação de outro membro. Nunca commitar `terraform.tfvars` nem state com segredos.

## Time — Grupo 183

Roberta Lima (Tech Lead) · Gustavo Delfino (Infra/CI-CD) · David Tavares (Infra/CI-CD) · Johny David (Aplicação)
