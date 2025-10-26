# iam.tf

# 1. EKS 클러스터(컨트롤 플레인)를 위한 IAM 역할
resource "aws_iam_role" "eks_kafka_cluster_role" {
  name = "eks-kafka-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# EKS 클러스터 역할에 필요한 정책 연결
resource "aws_iam_role_policy_attachment" "cluster_policy_attachment_kafka" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.eks_kafka_cluster_role.name
}


# 2. 워커 노드(EC2 인스턴스)를 위한 IAM 역할
resource "aws_iam_role" "eks_kafka_node_role" {
  name = "eks-kafka-node-role"

  # EC2 인스턴스가 이 역할을 맡을 수 있도록 허용
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# 워커 노드 역할에 필요한 3가지 기본 정책 연결
resource "aws_iam_role_policy_attachment" "node_policy_attachment_worker_kafka" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role = aws_iam_role.eks_kafka_node_role.name
}

resource "aws_iam_role_policy_attachment" "node_policy_attachment_cni_kafka" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role = aws_iam_role.eks_kafka_node_role.name
}

resource "aws_iam_role_policy_attachment" "node_policy_attachment_ecr_kafka" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role = aws_iam_role.eks_kafka_node_role.name
}