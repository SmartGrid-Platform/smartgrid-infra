terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
  }

  backend "s3" {
    bucket         = "smartgrid-tf-state-inky0p"
    key            = "terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# Secondary provider for WAF in us-east-1 (CloudFront requirement)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "kubernetes" {
  host                   = module.smartgrid_core.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.smartgrid_core.eks_cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.smartgrid_core.eks_cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.smartgrid_core.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.smartgrid_core.eks_cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.smartgrid_core.eks_cluster_name]
      command     = "aws"
    }
  }
}

