#################################################
# AWS Load Balancer Controller Setup
# (Requires kubernetes and helm providers)
#################################################

# 1. IAM Policy for AWS Load Balancer Controller
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy-${var.environment}"
  path        = "/"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeRouteTables",
          "ec2:DescribeInstances",
          "ec2:DescribeCoipPools",
          "ec2:DescribeLocalGatewayRouteTableVirtualInterfaceGroupAssociations",
          "ec2:DescribeLocalGatewayRouteTables",
          "ec2:DescribeLocalGatewayRouteTableVpcAssociations",
          "ec2:DescribeLocalGateways",
          "ec2:DescribeLocalGatewayVirtualInterfaces",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeTrustStores"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "waf:GetWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:DescribeProtection",
          "shield:GetSubscriptionState",
          "shield:DeleteProtection",
          "shield:CreateProtection",
          "shield:DescribeSubscription"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      }
    ]
  })
}

# 2. IAM Role for AWS Load Balancer Controller
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "smartgrid-${var.environment}-aws-lb-controller"

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
            "${replace(aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_attach" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# 3. Install AWS Load Balancer Controller via local kubectl + helm CLIs.
#
# Using null_resource instead of the Terraform kubernetes/helm providers
# avoids the chicken-and-egg problem: those providers need a live cluster
# endpoint to initialise, but the cluster doesn't exist yet on first apply.
# null_resource runs AFTER the node group is ACTIVE so the cluster is ready.
#
# Prerequisites on the machine running terraform apply:
#   - aws CLI configured with the deployment credentials
#   - kubectl  (https://kubernetes.io/docs/tasks/tools/)
#   - helm     (https://helm.sh/docs/intro/install/)
resource "null_resource" "install_lbc" {
  # Re-run whenever the cluster name, IAM role, or VPC changes
  triggers = {
    cluster_name = aws_eks_cluster.eks.name
    role_arn     = aws_iam_role.aws_load_balancer_controller.arn
    aws_region   = var.aws_region
    vpc_id       = aws_vpc.smartgrid_vpc.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      echo "--- Updating kubeconfig ---"
      aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.eks.name}

      echo "--- Waiting for nodes to be Ready (up to 5 min) ---"
      kubectl wait --for=condition=Ready nodes --all --timeout=300s

      echo "--- Creating LBC ServiceAccount with IRSA annotation ---"
      kubectl create serviceaccount aws-load-balancer-controller -n kube-system --dry-run=client -o yaml | kubectl apply -f -
      kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
        eks.amazonaws.com/role-arn=${aws_iam_role.aws_load_balancer_controller.arn} --overwrite

      echo "--- Installing AWS Load Balancer Controller via Helm ---"
      helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
      helm repo update eks

      helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true
      sleep 10

      helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        --namespace kube-system \
        --version 1.8.1 \
        --set clusterName=${aws_eks_cluster.eks.name} \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set region=${var.aws_region} \
        --set vpcId=${aws_vpc.smartgrid_vpc.id} \
        --set replicaCount=1 \
        --wait --timeout 10m

      echo "--- LBC installed successfully ---"
    EOT
  }

  # On destroy: uninstall Helm releases before the cluster is torn down so
  # the LBC-created ALBs are deleted and the VPC can be destroyed cleanly.
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      aws eks update-kubeconfig --region ${self.triggers.aws_region} --name ${self.triggers.cluster_name} 2>/dev/null || true
      helm uninstall smartgrid -n default 2>/dev/null || true
      helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true
      kubectl delete serviceaccount aws-load-balancer-controller -n kube-system 2>/dev/null || true
    EOT
  }

  depends_on = [
    aws_eks_node_group.nodes,
    aws_iam_role_policy_attachment.aws_load_balancer_controller_attach
  ]
}
