module "eks" {
  source       = "./modules/eks-cluster"
  cluster_name = var.cluster_name
  node_count   = var.node_count
  instance_type = var.instance_type
  aws_region   = var.aws_region
}
