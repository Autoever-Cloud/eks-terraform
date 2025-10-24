# main.tf

provider "aws" {
  region = var.region
}

# 1. MSK Serverless를 위한 새 보안 그룹 생성
resource "aws_security_group" "msk_sg" {
  name        = "${var.cluster_name}-sg"
  description = "Allow traffic to MSK Serverless cluster"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.cluster_name}-sg"
  }
}

# 2. EKS 워커 노드 -> MSK 보안 그룹으로의 트래픽 허용 (IAM 인증 포트 9098)
resource "aws_security_group_rule" "allow_eks_to_msk" {
  type                     = "ingress"
  from_port                = 9098 # MSK Serverless는 IAM 인증에 9098 포트만 사용
  to_port                  = 9098
  protocol                 = "tcp"
  source_security_group_id = var.eks_worker_security_group_id # EKS 워커 노드 보안 그룹
  security_group_id        = aws_security_group.msk_sg.id
  description              = "Allow EKS workers to connect to MSK on port 9098"
}

# 3. MSK Serverless 클러스터 본체 생성
resource "aws_msk_serverless_cluster" "my_msk" {
  cluster_name = var.cluster_name

  vpc_config {
    subnet_ids = var.private_subnet_ids
    security_group_ids = [
      aws_security_group.msk_sg.id
    ]
  }

  client_authentication {
    sasl {
      iam {
        enabled = true # Serverless는 IAM 인증이 필수입니다.
      }
    }
  }

  tags = {
    Name    = var.cluster_name
    Managed = "Terraform"
  }
}

# 4. 생성된 클러스터의 Bootstrap Server 주소를 출력 (핵심!)
output "msk_bootstrap_servers_iam" {
  description = "MSK Serverless (IAM) Bootstrap Servers FQDN"
  value       = aws_msk_serverless_cluster.my_msk.bootstrap_brokers_sasl_iam
}
