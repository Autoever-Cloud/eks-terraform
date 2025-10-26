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
    }
    # ... 팀원 추가 ...
  ]
}

# --- 2. DataCenter 클러스터 권한 설정 ---

# 2-1. DataCenter 클러스터의 'aws-auth' ConfigMap을 읽어옵니다.
data "kubernetes_config_map" "aws_auth_datacenter" {
  provider = kubernetes.datacenter
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
}

# 2-2. DataCenter 클러스터의 'aws-auth'를 수정(Patch)합니다.
resource "kubernetes_config_map_v1_data" "aws_auth_patch_datacenter" {
  provider = kubernetes.datacenter 
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  data = {
    "mapUsers" = yamlencode(concat(
      try(yamldecode(data.kubernetes_config_map.aws_auth_datacenter.data.mapUsers), []),
      local.map_users
    ))
  }
  depends_on = [
    aws_eks_node_group.datacenter_nodegroup 
  ]
}

# --- 3. Kafka 클러스터 권한 설정 ---

# 3-1. Kafka 클러스터의 'aws-auth' ConfigMap을 읽어옵니다.
data "kubernetes_config_map" "aws_auth_kafka" {
  provider = kubernetes.kafka 
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
}

# 3-2. Kafka 클러스터의 'aws-auth'를 수정(Patch)합니다.
resource "kubernetes_config_map_v1_data" "aws_auth_patch_kafka" {
  provider = kubernetes.kafka 
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  data = {
    "mapUsers" = yamlencode(concat(
      try(yamldecode(data.kubernetes_config_map.aws_auth_kafka.data.mapUsers), []),
      local.map_users
    ))
  }
  depends_on = [
    aws_eks_node_group.kafka_nodegroup 
  ]
}


# --- 4. Monitoring 클러스터 권한 설정 ---

# 4-1. Monitoring 클러스터의 'aws-auth' ConfigMap을 읽어옵니다.
data "kubernetes_config_map" "aws_auth_monitoring" {
  provider = kubernetes.monitoring 
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
}

# 4-2. Monitoring 클러스터의 'aws-auth'를 수정(Patch)합니다.
resource "kubernetes_config_map_v1_data" "aws_auth_patch_monitoring" {
  provider = kubernetes.monitoring 
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
    }
  data = {
    "mapUsers" = yamlencode(concat(
      try(yamldecode(data.kubernetes_config_map.aws_auth_monitoring.data.mapUsers), []),
      local.map_users
    ))
  }
  depends_on = [
    aws_eks_node_group.monitoring_nodegroup 
  ]
}