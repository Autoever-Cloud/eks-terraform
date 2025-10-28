# vpc.tf
# [비용 절감형] 1개 VPC, 2개 AZ, 2개 서브넷으로 3개 클러스터 모두 공유

# 1. VPC 생성
resource "aws_vpc" "solog_vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "solog-unified-vpc"
  }
}

# 2. 퍼블릭 서브넷 "2개" 생성 (2개 AZ)
resource "aws_subnet" "solog_public_subnets" {
  count                   = 2
  vpc_id                  = aws_vpc.solog_vpc.id
  availability_zone       = ["ap-northeast-2a", "ap-northeast-2c"][count.index]
  cidr_block              = "192.168.${count.index}.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "solog-unified-public-subnet-${count.index + 1}"

    # 3개 클러스터 이름을 모두 태그
    "kubernetes.io/cluster/eks-datacenter-cluster" = "shared"
    "kubernetes.io/cluster/eks-kafka-cluster"      = "shared"
    "kubernetes.io/cluster/eks-monitoring-cluster" = "shared"
  }
}

# 3. 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "solog_igw" {
  vpc_id = aws_vpc.solog_vpc.id

  tags = {
    Name = "solog-unified-igw"
  }
}

# 4. 라우트 테이블 (Public) 생성
resource "aws_route_table" "solog_public_rt" {
  vpc_id = aws_vpc.solog_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.solog_igw.id
  }

  tags = {
    Name = "solog-unified-public-rt"
  }
}

# 5. 서브넷 2개를 라우트 테이블에 연결
resource "aws_route_table_association" "solog_public_rta" {
  count          = 2
  subnet_id      = aws_subnet.solog_public_subnets[count.index].id
  route_table_id = aws_route_table.solog_public_rt.id
}