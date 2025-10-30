# addons.tf

# ==========================================================
# 1. OIDC (IRSA) 설정
# ==========================================================
# EKS 클러스터가 생성되면 OIDC Issuer URL이 나옵니다.
# 이 URL에 접속해서 인증서 지문(thumbprint)을 가져옵니다.

data "tls_certificate" "datacenter_oidc" {
  url = aws_eks_cluster.datacenter_cluster.identity[0].oidc[0].issuer
}
data "tls_certificate" "monitoring_oidc" {
  url = aws_eks_cluster.monitoring_cluster.identity[0].oidc[0].issuer
}


resource "aws_iam_openid_connect_provider" "datacenter_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.datacenter_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.datacenter_cluster.identity[0].oidc[0].issuer
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
  cluster_name                = aws_eks_cluster.datacenter_cluster.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  service_account_role_arn = aws_iam_role.eks_datacenter_ebs_csi_role.arn
  # OIDC 공급자 생성이 완료된 후에 애드온을 설치하도록 순서 보장
  depends_on = [
    aws_eks_node_group.datacenter_nodegroup # 노드 그룹이 준비된 후 설치
  ]
}

resource "aws_eks_addon" "monitoring_ebs_csi" {
  cluster_name                = aws_eks_cluster.monitoring_cluster.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  service_account_role_arn = aws_iam_role.eks_monitoring_ebs_csi_role.arn

  depends_on = [
    aws_eks_node_group.monitoring_nodegroup
  ]
}

# ==========================================================
# 3. [신규] EFS CSI Driver 애드온 설치
# (IAM 역할은 iam_*.tf 파일이 관리)
# ==========================================================
resource "aws_eks_addon" "datacenter_efs_csi" {
  cluster_name                = aws_eks_cluster.datacenter_cluster.name
  addon_name                  = "aws-efs-csi-driver" # 애드온 이름
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  # iam_datacenter.tf 에서 방금 만든 EFS 역할 ARN을 명시적으로 연결
  service_account_role_arn = aws_iam_role.eks_datacenter_efs_csi_role.arn
  depends_on               = [
    aws_eks_node_group.datacenter_nodegroup
  ]
}