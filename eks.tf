# Rede (conta pessoal)

data "aws_vpc" "default" {
  count   = var.use_default_vpc ? 1 : 0
  default = true
}

# us-east-1e não suporta control plane de EKS
data "aws_availability_zones" "available" {
  count = var.use_default_vpc ? 1 : 0
  state = "available"
}

data "aws_subnets" "default" {
  count = var.use_default_vpc ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }

  filter {
    name   = "availability-zone"
    values = [for az in data.aws_availability_zones.available[0].names : az if !contains(var.eks_excluded_azs, az)]
  }
}

locals {
  subnet_ids       = var.use_default_vpc ? data.aws_subnets.default[0].ids : var.subnet_ids
  cluster_role_arn = var.create_iam_roles ? aws_iam_role.eks_cluster[0].arn : var.lab_role_arn
  node_role_arn    = var.create_iam_roles ? aws_iam_role.eks_node[0].arn : var.lab_role_arn
}

# IAM (conta pessoal)

data "aws_iam_policy_document" "eks_cluster_assume" {
  count = var.create_iam_roles ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  count              = var.create_iam_roles ? 1 : 0
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume[0].json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.create_iam_roles ? 1 : 0
  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "eks_node_assume" {
  count = var.create_iam_roles ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  count              = var.create_iam_roles ? 1 : 0
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume[0].json
}

resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  count      = var.create_iam_roles ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  count      = var.create_iam_roles ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  count      = var.create_iam_roles ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --- Cluster ---

resource "aws_eks_cluster" "oficina" {
  name     = var.cluster_name
  role_arn = local.cluster_role_arn

  vpc_config {
    subnet_ids              = local.subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  tags = {
    Project = "oficina-mecanica"
    Stack   = "k8s"
  }
}

# Hop limit 2 no IMDS dos nos. Com o padrao 1, pods fora da rede do host
# (como o controller do driver EBS) nao alcancam o servico de metadados e nao
# obtem credenciais: o driver falhava com "get identity". Visto em 15/11.
resource "aws_launch_template" "oficina_nodes" {
  name_prefix = "${var.cluster_name}-nodes-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Project = "oficina-mecanica"
    Stack   = "k8s"
  }
}

resource "aws_eks_node_group" "oficina_nodes" {
  cluster_name    = aws_eks_cluster.oficina.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = local.node_role_arn
  subnet_ids      = local.subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  instance_types = var.node_instance_types

  launch_template {
    id      = aws_launch_template.oficina_nodes.id
    version = aws_launch_template.oficina_nodes.latest_version
  }

  depends_on = [
    aws_eks_cluster.oficina,
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_cni,
  ]

  tags = {
    Project = "oficina-mecanica"
    Stack   = "k8s"
  }
}

# Driver EBS CSI. Sem ele o cluster nao cria volume nenhum: o provisionador
# antigo kubernetes.io/aws-ebs (da storage class gp2 que vem no EKS) nao
# funciona mais, e os StatefulSets dos bancos ficavam Pending para sempre.
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.oficina.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [aws_eks_node_group.oficina_nodes]
}

# Storage class padrao. Os PVCs dos bancos da Fase 4 nao declaram classe, e
# o EKS nao marca nenhuma como padrao: sem esta, ficam Pending.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "ebs-gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  reclaim_policy      = "Delete"

  parameters = {
    type = "gp3"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}
