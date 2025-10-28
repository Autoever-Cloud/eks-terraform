# provider.tf

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0" 
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
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
  region = "ap-northeast-2"
  profile = "JWON" 
}

# 2. Kubernetes 프로바이더 (클러스터 "내부" 관리용)
# --- 3개 클러스터에 대한 접속 정보를 각각 정의 ---

provider "kubernetes" {
  alias = "datacenter" 
  host = aws_eks_cluster.datacenter_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.datacenter_cluster.certificate_authority[0].data)
  exec {  
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", aws_eks_cluster.datacenter_cluster.name]
  }
}

#provider "kubernetes" {
#  alias = "kafka"
#  host  = aws_eks_cluster.kafka_cluster.endpoint
#  cluster_ca_certificate = base64decode(aws_eks_cluster.kafka_cluster.certificate_authority[0].data)
#  exec {
#    api_version = "client.authentication.k8s.io/v1beta1"
#    command     = "aws"
#    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.kafka_cluster.name]
#  }
#}

provider "kubernetes" {
  alias = "monitoring"
  host  = aws_eks_cluster.monitoring_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.monitoring_cluster.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.monitoring_cluster.name]
  }
}
