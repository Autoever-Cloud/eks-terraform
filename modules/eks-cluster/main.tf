data "aws_availability_zones" "available" {}

########################################
# 1️⃣ VPC + Subnet + 라우팅 구성
########################################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    Name = "${var.cluster_name}-public-${count.index}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.cluster_name}-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

########################################
# 2️⃣ 보안 그룹 설정 (Control Plane ↔ Node 간 통신 보장)
########################################
resource "aws_security_group" "eks_sg" {
  vpc_id = aws_vpc.main.id
  name   = "${var.cluster_name}-sg"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "EKS Control Plane communication"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-sg"
  }
}

########################################
# 3️⃣ EKS 클러스터 + 노드 그룹
########################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  vpc_id          = aws_vpc.main.id
  subnet_ids      = aws_subnet.public[*].id
  cluster_security_group_id = aws_security_group.eks_sg.id

  eks_managed_node_groups = {
    default = {
      desired_size    = var.node_count
      max_size        = var.node_count
      min_size        = 1
      instance_types  = [var.instance_type]

      # 안정적인 Amazon Linux 2 AMI 사용
      ami_type        = "AL2_x86_64"

      # Node IAM Role 연결
      node_role_arn   = aws_iam_role.eks_node_role.arn

      # 보안 그룹 적용
      vpc_security_group_ids = [aws_security_group.eks_sg.id]
    }
  }

  tags = {
    Environment = "prod"
    Terraform   = "true"
  }
}
