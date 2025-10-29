# provider.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# AWS 프로바이더 설정
provider "aws" {
  region  = "ap-northeast-2"
  profile = "JWON"
}

# 2. Kubernetes 프로바이더 (클러스터 "내부" 관리용)
# --- 3개 클러스터에 대한 접속 정보를 각각 정의 ---

# 2-1. DataCenter 클러스터 접속 정보
data "aws_eks_cluster" "datacenter" {
  name = aws_eks_cluster.datacenter_cluster.name
}
data "aws_eks_cluster_auth" "datacenter" {
  name = aws_eks_cluster.datacenter_cluster.name
}
provider "kubernetes" {
  alias                  = "datacenter" # "datacenter" 라는 별명 부여
  host                   = data.aws_eks_cluster.datacenter.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.datacenter.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.datacenter.token
}

# 2-2. Kafka 클러스터 접속 정보
data "aws_eks_cluster" "kafka" {
  name = aws_eks_cluster.kafka_cluster.name
}
data "aws_eks_cluster_auth" "kafka" {
  name = aws_eks_cluster.kafka_cluster.name
}
provider "kubernetes" {
  alias = "kafka"
  host = data.aws_eks_cluster.kafka.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.kafka.certificate_authority[0].data)
  token = data.aws_eks_cluster_auth.kafka.token
}

# 2-3. Monitoring 클러스터 접속 정보
data "aws_eks_cluster" "monitoring" {
  name = aws_eks_cluster.monitoring_cluster.name
}
data "aws_eks_cluster_auth" "monitoring" {
  name = aws_eks_cluster.monitoring_cluster.name
}
provider "kubernetes" {
  alias                  = "monitoring"
  host                   = data.aws_eks_cluster.monitoring.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.monitoring.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.monitoring.token
}