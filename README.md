# oficina-infra-k8s

Infraestrutura como código do cluster **Kubernetes (AWS EKS)** e do **API Gateway** do Tech Challenge SOAT — Fase 3 (Grupo 32).

> Repositório 2 de 4 da Fase 3. Ver também: [oficina-mecanica-api](https://github.com/Ralima0711/oficina-mecanica-api) · [oficina-lambda-auth](https://github.com/Ralima0711/oficina-lambda-auth) · [oficina-infra-database](https://github.com/Ralima0711/oficina-infra-database)

## Propósito

Provisionar, de forma reprodutível, o cluster EKS que executa a aplicação e o API Gateway que roteia e protege as rotas. Isolado do banco (repo `oficina-infra-database`) e da aplicação para permitir CI/CD independente.

## Tecnologias

| Tecnologia | Papel |
|---|---|
| Terraform (≥ 1.3) | Provisionamento da infraestrutura AWS |
| AWS EKS | Cluster Kubernetes gerenciado |
| AWS API Gateway | Roteamento e proteção das rotas da aplicação |
| Kubernetes HPA | Escalabilidade automática (min 2 / max 10 pods) |
| GitHub Actions | Pipeline CI/CD (`terraform plan` → `apply`) |

## Recursos provisionados

| Recurso | Detalhe |
|---|---|
| `aws_eks_cluster` | Cluster Kubernetes gerenciado |
| `aws_eks_node_group` | Node group t3.medium (1–4 nós) |
| API Gateway | Rota pública `/auth`; demais rotas exigem Bearer token |
| HPA | CPU 70% / Mem 80% — min 2, max 10 pods |

## Execução / Deploy

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

O deploy é automatizado via GitHub Actions nas branches `homolog` e `main`.

## Diagrama

```
API Gateway ──▶ EKS (pods da API + HPA) ──▶ RDS (repo oficina-infra-database)
```

## Regras de contribuição

Branch `main` protegida. Todo merge via **Pull Request** com aprovação de outro membro. Nunca commitar `terraform.tfvars` nem state com segredos.

## Time — Grupo 32

Roberta Lima (Tech Lead) · Gustavo Delfino (Infra/CI-CD) · David Tavares (Infra/CI-CD) · Johny David (Aplicação)
