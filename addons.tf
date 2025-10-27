# addons.tf

# ==========================================================
# 1. OIDC (IRSA) 설정
# ==========================================================
# EKS 클러스터가 생성되면 OIDC Issuer URL이 나옵니다.
# 이 URL에 접속해서 인증서 지문(thumbprint)을 가져옵니다.

data "tls_certificate" "datacenter_oidc" {
  url = aws_eks_cluster.datacenter_cluster.identity[0].oidc[0].issuer
}
data "tls_certificate" "kafka_oidc" {
  url = aws_eks_cluster.kafka_cluster.identity[0].oidc[0].issuer
}
data "tls_certificate" "monitoring_oidc" {
  url = aws_eks_cluster.monitoring_cluster.identity[0].oidc[0].issuer
}


resource "aws_iam_openid_connect_provider" "datacenter_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.datacenter_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.datacenter_cluster.identity[0].oidc[0].issuer
}
resource "aws_iam_openid_connect_provider" "kafka_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.kafka_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.kafka_cluster.identity[0].oidc[0].issuer
}
resource "aws_iam_openid_connect_provider" "monitoring_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.monitoring_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.monitoring_cluster.identity[0].oidc[0].issuer
}


# ==========================================================
# 2. EBS CSI Driver 애드온 설치
# ==========================================================

resource "aws_eks_addon" "datacenter_ebs_csi" {
  cluster_name      = aws_eks_cluster.datacenter_cluster.name
  addon_name        = "aws-ebs-csi-driver"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # OIDC 공급자 생성이 완료된 후에 애드온을 설치하도록 순서 보장
  depends_on = [
    aws_iam_openid_connect_provider.datacenter_oidc,
    aws_eks_node_group.datacenter_nodegroup # 노드 그룹이 준비된 후 설치
  ]
}

resource "aws_eks_addon" "kafka_ebs_csi" {
  cluster_name      = aws_eks_cluster.kafka_cluster.name
  addon_name        = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on = [
    aws_iam_openid_connect_provider.kafka_oidc,
    aws_eks_node_group.kafka_nodegroup
  ]
}

resource "aws_eks_addon" "monitoring_ebs_csi" {
  cluster_name      = aws_eks_cluster.monitoring_cluster.name
  addon_name        = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on = [
    aws_iam_openid_connect_provider.monitoring_oidc,
    aws_eks_node_group.monitoring_nodegroup
  ]
}