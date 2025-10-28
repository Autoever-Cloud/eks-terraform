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

# 3. kafka EBS CSI 드라이버용 IAM 역할 (IRSA)
resource "aws_iam_role" "eks_kafka_ebs_csi_role" {
  name = "eks-kafka-ebs-csi-role"

  # 1번에서 생성한 OIDC 공급자(클러스터)가 이 역할을 맡도록 허용
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          # OIDC 공급자의 ARN을 Federated Principal로 지정
          Federated = aws_iam_openid_connect_provider.kafka_oidc.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # kube-system 네임스페이스의 ebs-csi-controller-sa 서비스 어카운트만 허용
            "${replace(aws_iam_openid_connect_provider.kafka_oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

# 4. EBS CSI 역할에 AWS 관리형 정책 연결
resource "aws_iam_role_policy_attachment" "ebs_csi_policy_attachment_kafka" {
  # EBS 볼륨을 생성/삭제/연결/분리하는 데 필요한 권한
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.eks_kafka_ebs_csi_role.name
}

# --- 3-2. Kafka EFS CSI 드라이버용 IAM 역할 (IRSA) ---
resource "aws_iam_role" "eks_kafka_efs_csi_role" {
  name = "eks-kafka-efs-csi-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.kafka_oidc.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.kafka_oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:efs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "efs_csi_policy_attachment_kafka" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.eks_kafka_efs_csi_role.name
}