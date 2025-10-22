#!/bin/bash
set -e

echo "🚀 Terraform EKS Multi-Cluster 자동 배포 스크립트 시작"
echo "현재 디렉토리: $(pwd)"

# Terraform 초기화
terraform init -input=false

# 워크스페이스 생성 (존재하지 않으면 새로 생성)
for ws in datacenter kafka monitoring; do
  if ! terraform workspace list | grep -q "$ws"; then
    terraform workspace new $ws
  fi
done

# 클러스터별 파라미터 설정
declare -A clusters
clusters=( ["datacenter"]=2 ["kafka"]=4 ["monitoring"]=4 )

# 각 워크스페이스에 클러스터 생성
for ws in "${!clusters[@]}"; do
  echo "🛠️  ${ws}-cluster 생성 중 (${clusters[$ws]} nodes)"
  terraform workspace select $ws
  terraform apply -auto-approve \
    -var="cluster_name=${ws}-cluster" \
    -var="node_count=${clusters[$ws]}"
done

echo "✅ 모든 EKS 클러스터 생성 완료!"
