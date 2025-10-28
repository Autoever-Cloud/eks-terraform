# iam_datacenter.tf

# 1. DataCenter EKS 클러스터(컨트롤 플레인)를 위한 IAM 역할
resource "aws_iam_role" "eks_datacenter_cluster_role" {
  name = "eks-datacenter-cluster-role" # 고유 이름

  # EKS 서비스가 이 역할을 맡을 수 있도록 허용
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "eks.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# EKS 클러스터 역할에 필요한 정책 연결
resource "aws_iam_role_policy_attachment" "cluster_policy_attachment_datacenter" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_datacenter_cluster_role.name
}

# 2. DataCenter 워커 노드(EC2 인스턴스)를 위한 IAM 역할
resource "aws_iam_role" "eks_datacenter_node_role" {
  name = "eks-datacenter-node-role" # 고유 이름

  # EC2 인스턴스가 이 역할을 맡을 수 있도록 허용
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# 워커 노드 역할에 필요한 3가지 기본 정책 연결
resource "aws_iam_role_policy_attachment" "node_policy_attachment_worker_datacenter" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_datacenter_node_role.name
}

resource "aws_iam_role_policy_attachment" "node_policy_attachment_cni_datacenter" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_datacenter_node_role.name
}

resource "aws_iam_role_policy_attachment" "node_policy_attachment_ecr_datacenter" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_datacenter_node_role.name
}

# 3. DataCenter EBS CSI 드라이버용 IAM 역할 (IRSA)
resource "aws_iam_role" "eks_datacenter_ebs_csi_role" {
  name = "eks-datacenter-ebs-csi-role"

  # 1번에서 생성한 OIDC 공급자(클러스터)가 이 역할을 맡도록 허용
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          # OIDC 공급자의 ARN을 Federated Principal로 지정
          Federated = aws_iam_openid_connect_provider.datacenter_oidc.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # kube-system 네임스페이스의 ebs-csi-controller-sa 서비스 어카운트만 허용
            "${replace(aws_iam_openid_connect_provider.datacenter_oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

# 4. EBS CSI 역할에 AWS 관리형 정책 연결
resource "aws_iam_role_policy_attachment" "ebs_csi_policy_attachment_datacenter" {
  # EBS 볼륨을 생성/삭제/연결/분리하는 데 필요한 권한
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.eks_datacenter_ebs_csi_role.name
}

# ... (기존 1, 2, 3, 4번 EBS 역할 코드) ...

# 5. DataCenter EFS CSI 드라이버용 IAM 역할 (IRSA)
resource "aws_iam_role" "eks_datacenter_efs_csi_role" {
  name = "eks-datacenter-efs-csi-role"

  # addons.tf 에서 생성한 OIDC 공급자(클러스터)가 이 역할을 맡도록 허용
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          # OIDC 공급자의 ARN을 Federated Principal로 지정
          Federated = aws_iam_openid_connect_provider.datacenter_oidc.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # EFS CSI 드라이버의 기본 ServiceAccount 이름
            "${replace(aws_iam_openid_connect_provider.datacenter_oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:efs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

# 6. EFS CSI 역할에 AWS 관리형 정책 연결
resource "aws_iam_role_policy_attachment" "efs_csi_policy_attachment_datacenter" {
  # EFS 파일시스템에 접근하는 데 필요한 권한
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.eks_datacenter_efs_csi_role.name
}