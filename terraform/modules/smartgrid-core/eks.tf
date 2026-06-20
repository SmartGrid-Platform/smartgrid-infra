#################################################
# EKS Cluster & IAM Roles
#################################################

# 1. IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "smartgrid-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# 2. EKS Cluster
resource "aws_eks_cluster" "eks" {
  name     = "smartgrid-${var.environment}-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id,
      aws_subnet.private_app_a.id,
      aws_subnet.private_app_b.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# 3. IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_role" {
  name = "smartgrid-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# 4. EKS Node Group (deploy in Private App Subnets)
resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "smartgrid-${var.environment}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]

  scaling_config {
    desired_size = var.asg_min_size
    max_size     = var.asg_max_size
    min_size     = var.asg_min_size
  }

  instance_types = [var.instance_type == "t2.micro" ? "t3.medium" : var.instance_type]

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_registry_policy,
    # Nodes live in private subnets and must reach the EKS public API endpoint
    # via the NAT gateway to complete bootstrap. Without these explicit deps,
    # Terraform can race the node group creation ahead of the NAT/route setup
    # (especially when the cluster already exists from a prior run), causing
    # NodeCreationFailure: Instances failed to join the kubernetes cluster.
    aws_route_table_association.private_app_a,
    aws_route_table_association.private_app_b
  ]
}

# 5. OIDC Provider configuration for EKS (IRSA)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

# 6. IAM Role & Policy for EKS Pods (ServiceAccount smartgrid-sa)
resource "aws_iam_role" "eks_pod_role" {
  name = "smartgrid-${var.environment}-eks-pod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:default:smartgrid-sa"
          }
        }
      }
    ]
  })
}

# Attach backend permissions policy to this EKS Pod Role
resource "aws_iam_role_policy_attachment" "eks_pod_policy_attach" {
  role       = aws_iam_role.eks_pod_role.name
  policy_arn = aws_iam_policy.backend_policy.arn
}

#################################################
# ECR Container Registries
#################################################

data "aws_caller_identity" "current" {}

resource "aws_ecr_repository" "smartgrid_repos" {
  for_each             = toset(["auth-service", "consumer-service", "meter-service", "billing-service", "alert-service", "ai-assistant-service", "frontend"])
  name                 = "smartgrid-${var.environment}-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
    Project     = "smartgrid"
  }
}

