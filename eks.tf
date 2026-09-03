data "aws_subnet" "selected" {
  id = var.subnet_ids[0]
}

data "aws_vpc" "selected" {
  id = data.aws_subnet.selected.vpc_id
}

resource "aws_eks_cluster" "oficina" {
  name     = var.cluster_name
  role_arn = var.lab_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
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
  node_role_arn   = var.lab_role_arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  instance_types = var.node_instance_types

  depends_on = [aws_eks_cluster.oficina]

  tags = {
    Project = "oficina-mecanica"
    Stack   = "k8s"
  }
}
