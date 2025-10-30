resource "aws_security_group" "msk_sg" {
  name        = "solog-msk-sg"
  description = "Allow inbound traffic from EKS worker nodes to MSK"
  vpc_id      = aws_vpc.solog_vpc.id

  # --- 인바운드 규칙 (Ingress) ---
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1" # 모든 프로토콜
    security_groups = [aws_eks_cluster.datacenter_cluster.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_eks_cluster.monitoring_cluster.vpc_config[0].cluster_security_group_id]
  }

  # --- 아웃바운드 규칙 (Egress) ---
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "solog-msk-sg"
  }
}

# 3. AWS MSK 클러스터 생성 (KRaft + EBS)
resource "aws_msk_cluster" "msk_cluster" {
  cluster_name = "solog-msk-cluster"
  kafka_version = "3.6.0"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type = "kafka.t3.small"

    client_subnets = [
      for s in aws_subnet.solog_public_subnets : s.id
    ]
    security_groups = [aws_security_group.msk_sg.id]

    storage_info {
      ebs_storage_info {
        volume_size = 100
      }
    }
  }

  # --- 보안 및 인증 설정 --- 안해~
  client_authentication {
    #sasl {
      #iam = true
    #}
    unauthenticated = true
  }

  # 전송 중 암호화 (네트워크 트래픽 암호화)
  encryption_info {
    encryption_in_transit {
      client_broker = "TLS_PLAINTEXT" # TLS_PLAINTEXT, TLS 중 선택
    }
  }

  tags = {
    Name = "solog-msk-cluster"
  }

  depends_on = [
    aws_security_group.msk_sg,
    aws_eks_cluster.datacenter_cluster,
    aws_eks_cluster.monitoring_cluster
  ]
} 

# 4. (선택) 생성된 MSK 클러스터 정보 출력

output "msk_cluster_arn" {
  description = "생성된 MSK 클러스터의 ARN"
  value       = aws_msk_cluster.msk_cluster.arn
}

output "msk_bootstrap_servers_iam" {
  description = "IAM 인증용 부트스트랩 서버 주소"
  value       = aws_msk_cluster.msk_cluster.bootstrap_brokers_sasl_iam
}

output "msk_bootstrap_servers_tls" {
  description = "TLS 인증용 부트스트랩 서버 주소"
  value       = aws_msk_cluster.msk_cluster.bootstrap_brokers_tls
}

output "msk_bootstrap_servers_plaintext" {
  description = "Plaintext (비인증, 9092 포트) 부트스트랩 서버 주소"
  value       = aws_msk_cluster.msk_cluster.bootstrap_brokers
}