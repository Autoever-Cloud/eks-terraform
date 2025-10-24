# variables.tf

variable "vpc_id" {
  description = "MSK 클러스터를 배포할 VPC의 ID"
  type        = string
  # 예: "vpc-0123456789abcdef0"
}

variable "private_subnet_ids" {
  description = "MSK 클러스터가 사용할 Private Subnet ID 목록 (최소 2개 이상)"
  type        = list(string)
  # 예: ["subnet-0a1b2c3d...", "subnet-0d4e5f6a..."]
}

variable "eks_worker_security_group_id" {
  description = "MSK에 접근해야 하는 EKS Worker Node의 보안 그룹 ID"
  type        = string
  # 예: "sg-0abcdef1234567890"
}

variable "cluster_name" {
  description = "생성할 MSK Serverless 클러스터의 이름"
  type        = string
  default     = "my-log-msk-cluster"
}

variable "region" {
  description = "배포할 AWS 리전"
  type        = string
  default     = "ap-northeast-2" # 서울 리전
}
