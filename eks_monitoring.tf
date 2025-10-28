# eks.tf

# 1. EKS 클러스터(컨트롤 플레인) 생성
resource "aws_eks_cluster" "monitoring_cluster" {
  name     = "eks-monitoring-cluster"
  version  = "1.30"
  role_arn = aws_iam_role.eks_monitoring_cluster_role.arn

  # 클러스터가 사용할 VPC 및 서브넷 정보
  vpc_config {
    subnet_ids = [for s in aws_subnet.solog_public_subnets : s.id]
  }

  # EKS 클러스터 리소스가 VPC, IAM 역할보다 늦게 생성되도록 의존성 설정
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy_attachment_monitoring,
    aws_vpc.solog_vpc,
  ]
}
# 1. EKS 노드를 위한 시작 템플릿 생성
resource "aws_launch_template" "monitoring_lt" {
  name = "eks-monitoring-lt"

  instance_type = "t3.medium" 

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "eks-monitoring-node" 
      ClusterName = "eks-monitoring-cluster"
      ManagedBy   = "Terraform"
    }
  }
}

# 2. EKS 노드 그룹 생성
resource "aws_eks_node_group" "monitoring_nodegroup" {
  cluster_name    = aws_eks_cluster.monitoring_cluster.name
  node_group_name = "eks-monitoring-nodegroup"  
  node_role_arn   = aws_iam_role.eks_monitoring_node_role.arn
  subnet_ids      = [for s in aws_subnet.solog_public_subnets : s.id]

  launch_template {
    id      = aws_launch_template.monitoring_lt.id
    version = aws_launch_template.monitoring_lt.latest_version
  }

  # 오토스케일링 설정
  scaling_config {
    desired_size = 2
    min_size     = 2 
    max_size     = 4 
  }
  tags = {
    "Name"        = "eks-monitoring-asg-general"
    "ClusterName" = "eks-monitoring-cluster" 
    "ManagedBy"   = "Terraform"         
  }
  # 노드 그룹이 클러스터와 IAM 역할 생성 이후에 만들어지도록 의존성 설정
  depends_on = [
    aws_iam_role_policy_attachment.node_policy_attachment_worker_monitoring,
    aws_iam_role_policy_attachment.node_policy_attachment_cni_monitoring,
    aws_iam_role_policy_attachment.node_policy_attachment_ecr_monitoring,
  ]
}

# 3. EKS 노드 그룹 - kafka connect 전용 노드그룹 
resource "aws_eks_node_group" "monitoring_nodegroup_connect" {
  cluster_name    = aws_eks_cluster.monitoring_cluster.name
  node_group_name = "eks-monitoring-connect-nodegroup"  
  node_role_arn   = aws_iam_role.eks_monitoring_node_role.arn
  subnet_ids      = [for s in aws_subnet.solog_public_subnets : s.id]

  launch_template {
    id      = aws_launch_template.monitoring_lt.id
    version = aws_launch_template.monitoring_lt.latest_version
  }

  # 오토스케일링 설정
  scaling_config {
    desired_size = 1 
    min_size     = 1 
    max_size     = 2 
  }
  taint {
    key    = "app"
    value  = "kafka-connect"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "dedicated" = "kafka-connect"
  }

  tags = {
    "Name"        = "eks-monitoring-asg-connect"
    "ClusterName" = "eks-monitoring-cluster" 
    "ManagedBy"   = "Terraform"         
  }
  # 노드 그룹이 클러스터와 IAM 역할 생성 이후에 만들어지도록 의존성 설정
  depends_on = [
    aws_iam_role_policy_attachment.node_policy_attachment_worker_monitoring,
    aws_iam_role_policy_attachment.node_policy_attachment_cni_monitoring,
    aws_iam_role_policy_attachment.node_policy_attachment_ecr_monitoring,
  ]
}