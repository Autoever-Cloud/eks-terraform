# efs.tf
# 공유 EFS 파일시스템 및 3개 클러스터의 StorageClass 자동 생성

# ==========================================================
# 1. 공유 EFS 파일 시스템 생성
# ==========================================================
resource "aws_efs_file_system" "solog_efs" {
  creation_token = "solog-shared-efs" # 중복 생성을 방지하는 고유 토큰

  tags = {
    Name = "solog-unified-efs"
  }
}

# ==========================================================
# 2. EFS 마운트 대상용 보안 그룹 (EFS-SG)
# ==========================================================
resource "aws_security_group" "solog_efs_sg" {
  name        = "solog-unified-efs-sg"
  description = "Allow NFS traffic from EKS nodes"
  vpc_id      = aws_vpc.solog_vpc.id

  tags = {
    Name = "solog-unified-efs-sg"
  }
}

# 3. 3개 클러스터의 노드 -> EFS-SG로의 NFS(2049) 트래픽 허용
# 3-1. DataCenter 노드 -> EFS-SG
resource "aws_security_group_rule" "allow_nfs_from_datacenter_nodes" {
  type                      = "ingress"
  from_port                 = 2049 # NFS
  to_port                   = 2049 # NFS
  protocol                  = "tcp"
  security_group_id         = aws_security_group.solog_efs_sg.id
  # DataCenter 클러스터의 기본 보안 그룹을 소스로 지정
  source_security_group_id = aws_eks_cluster.datacenter_cluster.vpc_config[0].cluster_security_group_id
}

# 3-3. Monitoring 노드 -> EFS-SG
resource "aws_security_group_rule" "allow_nfs_from_monitoring_nodes" {
  type                      = "ingress"
  from_port                 = 2049
  to_port                   = 2049
  protocol                  = "tcp"
  security_group_id         = aws_security_group.solog_efs_sg.id
  source_security_group_id = aws_eks_cluster.monitoring_cluster.vpc_config[0].cluster_security_group_id
}

# ==========================================================
# 4. EFS 마운트 대상 생성 (2개 서브넷)
# ==========================================================
resource "aws_efs_mount_target" "solog_efs_mt" {
  count           = 2 
  file_system_id  = aws_efs_file_system.solog_efs.id
  subnet_id       = aws_subnet.solog_public_subnets[count.index].id
  security_groups = [aws_security_group.solog_efs_sg.id]

  # EKS 클러스터의 보안 그룹 규칙이 먼저 생성되어야 함
  depends_on = [
    aws_security_group_rule.allow_nfs_from_datacenter_nodes,
    aws_security_group_rule.allow_nfs_from_monitoring_nodes
  ]
}

# ==========================================================
# 5. [자동화] 3개 클러스터에 StorageClass 생성
# (이전 단계의 sc-efs.yaml 수동 적용을 대체합니다)
# ==========================================================

# 5-1. DataCenter 클러스터에 StorageClass 생성
resource "kubernetes_storage_class_v1" "efs_sc_datacenter" {
  provider = kubernetes.datacenter # provider.tf의 별명 사용

  metadata {
    name = "efs-sc" # 공통 StorageClass 이름
  }
  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "Immediate"
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.solog_efs.id # 1번에서 생성한 EFS ID
    directoryPerms   = "700"
  }

  # EFS 애드온이 먼저 설치되어야 함
  depends_on = [aws_eks_addon.datacenter_efs_csi]
}

# 5-3. Monitoring 클러스터에 StorageClass 생성
resource "kubernetes_storage_class_v1" "efs_sc_monitoring" {
  provider = kubernetes.monitoring # provider.tf의 별명 사용

  metadata {
    name = "efs-sc"
  }
  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "Immediate"
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.solog_efs.id
    directoryPerms   = "700"
  }

  depends_on = [aws_eks_addon.monitoring_efs_csi]
}
