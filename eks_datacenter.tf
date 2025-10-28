# eks_datacenter.tf

# 1. EKS 클러스터(컨트롤 플레인) 생성
resource "aws_eks_cluster" "datacenter_cluster" {
  name     = "eks-datacenter-cluster"
  version  = "1.30"
  role_arn = aws_iam_role.eks_datacenter_cluster_role.arn

  # 클러스터가 사용할 VPC 및 서브넷 정보 (공유 서브넷 참조)
  vpc_config {
    subnet_ids = [for s in aws_subnet.solog_public_subnets : s.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy_attachment_datacenter,
    aws_vpc.solog_vpc,
  ]
}

resource "aws_launch_template" "datacenter_lt" {
  name = "eks-datacenter-lt"

  instance_type = "t3.medium"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "eks-datacenter-node"
      ClusterName = "eks-datacenter-cluster"
      ManagedBy   = "Terraform"
    }
  }
}

# 2. EKS 노드 그룹 생성
resource "aws_eks_node_group" "datacenter_nodegroup" {
  cluster_name    = aws_eks_cluster.datacenter_cluster.name
  node_group_name = "eks-datacenter-nodegroup"
  node_role_arn   = aws_iam_role.eks_datacenter_node_role.arn
  subnet_ids      = [for s in aws_subnet.solog_public_subnets : s.id]

  launch_template {
    id      = aws_launch_template.datacenter_lt.id
    version = aws_launch_template.datacenter_lt.latest_version
  }

  scaling_config {
    desired_size = 3
    min_size     = 3
    max_size     = 5
  }

  tags = {
    "Name"        = "eks-datacenter-asg"
    "ClusterName" = "eks-datacenter-cluster"
    "ManagedBy"   = "Terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policy_attachment_worker_datacenter,
    aws_iam_role_policy_attachment.node_policy_attachment_cni_datacenter,
    aws_iam_role_policy_attachment.node_policy_attachment_ecr_datacenter,
  ]
}