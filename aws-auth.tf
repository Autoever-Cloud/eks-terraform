# 1. 팀원 목록을 정의합니다. (이 목록은 3개 클러스터가 공유)
locals {
  map_users = [
    {
      userarn  = "arn:aws:iam::484400672545:user/MJ"
      username = "MJ"
      groups   = ["system:masters"] # 관리자 권한
    },
    {
      userarn  = "arn:aws:iam::484400672545:user/JWOO"
      username = "JWOO"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::484400672545:user/JJ"
      username = "JJ"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::484400672545:user/HS"
      username = "HS"
      groups   = ["system:masters"]
    }
  ]
}

# --- 2. DataCenter 클러스터 권한 설정 ---

# 2-1. DataCenter 클러스터의 'aws-auth' ConfigMap을 읽어옵니다.
resource "kubernetes_config_map" "aws_auth_datacenter" {
  provider = kubernetes.datacenter # DataCenter용 프로바이더 지정

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  data = {
    "mapRoles" = yamlencode([
      {
        rolearn  = aws_iam_role.eks_datacenter_node_role.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes",
        ]
      }
    ])
    "mapUsers" = yamlencode(local.map_users)
  }
  depends_on = [
    aws_iam_role.eks_datacenter_node_role
  ]
}

# --- 3. Kafka 클러스터 권한 설정 ---

#resource "kubernetes_config_map" "aws_auth_kafka" {
#  provider = kubernetes.kafka # Kafka용 프로바이더 지정
#
#  metadata {
#    name      = "aws-auth"
#    namespace = "kube-system"
#  }
#
#  data = {
#    "mapRoles" = yamlencode([
#      {
#        rolearn  = aws_iam_role.eks_kafka_node_role.arn
#        username = "system:node:{{EC2PrivateDNSName}}"
#        groups = [
#          "system:bootstrappers",
#          "system:nodes",
#        ]
#      }
#    ])
#    "mapUsers" = yamlencode(local.map_users)
#  }
#
#  depends_on = [
#    aws_iam_role.eks_kafka_node_role
#  ]
#}
# --- 4. Monitoring 클러스터 권한 설정 ---
resource "kubernetes_config_map" "aws_auth_monitoring" {
  provider = kubernetes.monitoring # Monitoring용 프로바이더 지정

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    "mapRoles" = yamlencode([
      {
        # [확인 필요] Monitoring 노드 그룹의 IAM 역할 ARN (이름 추측)
        rolearn  = aws_iam_role.eks_monitoring_node_role.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes",
        ]
      }
    ])
    "mapUsers" = yamlencode(local.map_users)
  }

  depends_on = [
    aws_iam_role.eks_monitoring_node_role # [확인 필요] Monitoring 노드 역할 리소스 이름
  ]
}