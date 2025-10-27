# Terraform AWS Provider 설정
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" 
    }
  }
}

provider "aws" {
  region = "ap-northeast-2" 
}

# 1. 기존 리소스 정보 가져오기 (Data Sources)
# --- 1-1. 기존 VPC 정보 가져오기 ---
data "aws_vpc" "solog_vpc" {
  tags = {
    Name = "solog-unified-vpc"
  }
}

# --- 1-2. MSK 브로커를 배치할 기존 서브넷 정보 가져오기 ---
data "aws_subnets" "solog_public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.solog_vpc.id]
  }
  filter {
    name   = "tag:Name" # 또는 "tag:Tier" 등 식별 가능한 태그
    values = ["solog-unified-public-subnet-*"]
  }
}

# --- 1-3. 기존 EKS 워커 노드의 보안 그룹 정보 가져오기 ---
data "aws_security_group" "eks_producer_sg" {
  tags = {
    Name = "eks-cluster-sg-eks-datacenter-cluster-1029477356"
  }
}

data "aws_security_group" "eks_consumer_sg" {
  tags = {
    Name = "eks-cluster-sg-eks-monitoring-cluster-1453820597"
  }
}

# 2. MSK 클러스터를 위한 새 보안 그룹 생성
variable "kafka_ports" {
  description = "EKS가 MSK에 접속하기 위해 열어줄 Kafka 포트 목록"
  type        = list(number)
  default     = [9092, 9098, 9094] 
}

resource "aws_security_group" "msk_sg" {
  name        = "my-msk-cluster-sg"
  description = "Allow inbound traffic from EKS worker nodes to MSK"
  vpc_id      = data.aws_vpc.solog_vpc.id

  # --- 인바운드 규칙 (Ingress) ---
  ingress {
    from_port                = 0
    to_port                  = 0
    protocol                 = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- 아웃바운드 규칙 (Egress) ---
  # MSK가 외부(EKS 응답 등)와 통신하기 위해 모든 아웃바운드를 허용합니다.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-msk-cluster-sg"
  }
}


# 3. AWS MSK 클러스터 생성 (KRaft + EBS)
resource "aws_msk_cluster" "msk_cluster" {
  cluster_name = "solog-msk-cluster" 
  
  kafka_version = "3.6.0" 
  cluster_mode = "KRAFT"

  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type = "kafka.t3.small"

    client_subnets = data.aws_subnets.solog_public_subnets.ids
    security_groups = [aws_security_group.msk_sg.id]

    storage_info {
      ebs_storage_info {
        volume_size = 100 
        # volume_type = "GP3" # (선택) GP3 타입을 명시할 수 있습니다.
        # throughput = 125    # (선택) GP3 사용 시 처리량 (MiB/s)
      }
    }
  }

  # --- 보안 및 인증 설정 ---
  client_authentication {
    sasl {
      iam = {
        enabled = true
      }
    }
  }

#  # 전송 중 암호화 (네트워크 트래픽 암호화)
#  encryption_info {
#    # 클라이언트(EKS)와 브로커 간 TLS 암호화를 활성화합니다.
#    encryption_in_transit {
#      client_broker = "TLS" # PLAINTEXT, TLS_PLAINTEXT, TLS 중 선택
#    }
#    # EBS 볼륨 암호화는 기본적으로 AWS 관리형 키로 활성화됩니다.
#  }
#
  # (선택) CloudWatch 로깅 설정
  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = "msk-${aws_msk_cluster.msk_cluster.cluster_name}-broker-logs"
      }
    }
  }

  tags = {
    Name = "my-msk-cluster"
  }
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
