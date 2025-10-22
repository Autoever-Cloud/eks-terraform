data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  count = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# EKS 클러스터 생성
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access = true

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  eks_managed_node_groups = {
    default = {
      desired_size = var.node_count
      min_size     = 1
      max_size     = var.node_count
      instance_types = [var.instance_type]
      node_role_arn  = aws_iam_role.eks_node_role.arn
    }
  }

  tags = {
    Environment = "prod"
    Terraform   = "true"
  }
}
