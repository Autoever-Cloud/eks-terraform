# eks.tf

# 1. EKS 클러스터(컨트롤 플레인) 생성
resource "aws_eks_cluster" "kafka_cluster" {
  name     = "eks-kafka-cluster"
  version  = "1.30"
  role_arn = aws_iam_role.eks_kafka_cluster_role.arn

  # 클러스터가 사용할 VPC 및 서브넷 정보
  vpc_config {
    subnet_ids = [for s in aws_subnet.solog_public_subnets : s.id]
  }

  # EKS 클러스터 리소스가 VPC, IAM 역할보다 늦게 생성되도록 의존성 설정
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy_attachment_kafka,
    aws_vpc.solog_vpc,
  ]
}

# 2. EKS 노드 그룹 생성
resource "aws_eks_node_group" "kafka_nodegroup" {
  cluster_name    = aws_eks_cluster.kafka_cluster.name
  node_group_name = "eks-kafka-nodegroup"  
  node_role_arn   = aws_iam_role.eks_kafka_node_role.arn
  subnet_ids      = [for s in aws_subnet.solog_public_subnets : s.id]
  instance_types  = ["t3.medium"] 

  # 오토스케일링 설정
  scaling_config {
    desired_size = 3 # eksctl --nodes
    min_size     = 3 # eksctl --nodes-min
    max_size     = 5 # eksctl --nodes-max
  }
  
  # 노드 그룹이 클러스터와 IAM 역할 생성 이후에 만들어지도록 의존성 설정
  depends_on = [
    aws_iam_role_policy_attachment.node_policy_attachment_worker_kafka,
    aws_iam_role_policy_attachment.node_policy_attachment_cni_kafka,
    aws_iam_role_policy_attachment.node_policy_attachment_ecr_kafka,
  ]
}