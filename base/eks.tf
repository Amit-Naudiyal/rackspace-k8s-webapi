resource "tls_private_key" "loginpvtkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.loginpvtkey.private_key_pem
  filename        = "loginpvtkey.pem"
  file_permission = "0600"
}

resource "aws_key_pair" "loginpubkey" {
  key_name_prefix = local.key_name
  public_key      = tls_private_key.loginpvtkey.public_key_openssh

  tags = local.tags
}

resource "aws_security_group" "remote_access" {
  name_prefix = "${local.cluster_name}-remote-access"
  description = "Allow remote SSH access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = local.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.23.0"

  cluster_name    = "${local.cluster_name}"
  cluster_version = "${local.cluster_version}"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  #Restrict Public endpoint access to your public IP
  cluster_endpoint_public_access_cidrs = "${local.cluster_endpoint_access_ips}"

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.k8s-identity-role.arn
      username = "microservice-k8s-identity-ec2"
      groups   = ["system:masters"]
    },
  ]
  
  eks_managed_node_groups = {

    default_node_group = {
      create_launch_template = false
      launch_template_name   = ""

      min_size     = 2
      max_size     = 10
      desired_size = 2
      disk_size    = 50

      # Remote access
      remote_access = {
        ec2_ssh_key               = aws_key_pair.loginpubkey.key_name
        source_security_group_ids = [aws_security_group.remote_access.id]
      }
      
      instance_types = ["t3.medium"]
    }

  }
  
  tags = {
     createdBy = "microservice/base"
  }
}

##EC2 instance role that can be used as an Admin for kubectl commands:

resource "aws_iam_role" "k8s-identity-role" {
  name = "microservice-k8s-identity-ec2"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = local.tags
}

resource "aws_iam_instance_profile" "k8s-identity-profile" {
  name = "microservice-k8s-identity-ec2"
  role = aws_iam_role.k8s-identity-role.name
}


data "aws_eks_cluster" "default" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "default" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.default.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.default.token
}

## IAM Role for ServiceAccount

module "irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = local.eks_pod_role_name

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.app_namespace}:default"]
    }
  }

  role_policy_arns = {
    AmazonSSMReadOnlyAccess_Policy = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
  }

  tags = local.tags
}


module "cluster_autoscaler_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                        = "cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_ids   = [module.eks.cluster_id]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = local.tags
}
