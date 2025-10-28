# outputs.tf

# --- 1. DataCenter 클러스터 ---
output "datacenter_cluster_name" {
  description = "DataCenter EKS 클러스터 이름"
  value       = aws_eks_cluster.datacenter_cluster.name
}

output "datacenter_cluster_endpoint" {
  description = "DataCenter EKS 클러스터 엔드포인트 URL"
  value       = aws_eks_cluster.datacenter_cluster.endpoint
}

output "datacenter_kubeconfig_command" {
  description = "DataCenter 클러스터 접속을 위한 kubeconfig 업데이트 명령어"
  value       = "aws eks update-kubeconfig --region ap-northeast-2 --name ${aws_eks_cluster.datacenter_cluster.name} --profile JWON"
}

# --- 3. Monitoring 클러스터 ---
output "monitoring_cluster_name" {
  description = "Monitoring EKS 클러스터 이름"
  value       = aws_eks_cluster.monitoring_cluster.name
}

output "monitoring_cluster_endpoint" {
  description = "Monitoring EKS 클러스터 엔드포인트 URL"
  value       = aws_eks_cluster.monitoring_cluster.endpoint
}

output "monitoring_kubeconfig_command" {
  description = "Monitoring 클러스터 접속을 위한 kubeconfig 업데이트 명령어"
  value       = "aws eks update-kubeconfig --region ap-northeast-2 --name ${aws_eks_cluster.monitoring_cluster.name} --profile JWON"
}