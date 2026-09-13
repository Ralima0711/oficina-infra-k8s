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
