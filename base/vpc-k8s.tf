
data "aws_availability_zones" "available" {
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.0"

  name                 = "${var.prefix}-k8s-vpc"
  cidr                 = "172.16.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["172.16.1.0/24", "172.16.11.0/24", "172.16.21.0/24"]
  public_subnets       = ["172.16.2.0/24", "172.16.12.0/24", "172.16.22.0/24"]

  enable_nat_gateway   = false
  single_nat_gateway   = false
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

output "eks-vpc" {
  value = module.vpc.vpc_id
}

output "eks-cidr" {
  value = module.vpc.vpc_cidr_block
}

#######################
# VPC Endpoint for STS
#######################

resource "aws_vpc_endpoint" "sts" {
  
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type = "Interface"
  security_group_ids  = ["${aws_security_group.sts.id}"]
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true
}

resource "aws_security_group" "sts" {
  name_prefix = "k8s-vpc-endpoint-sts-"
  description = "STS VPC Endpoint Security Group"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "vpc_endpoint_sts_https" {
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = "${aws_security_group.sts.id}"
}

#######################
# VPC Endpoint for S3
#######################

resource "aws_vpc_endpoint" "s3" {

  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = module.vpc.private_route_table_ids
  policy = <<POLICY

{
    "Statement": [
        {
            "Action": "*",
            "Effect": "Allow",
            "Resource": "*",
            "Principal": "*"
        }
    ]
}
POLICY

}


#######################
# VPC Endpoint for EC2
#######################

resource "aws_vpc_endpoint" "ec2" {
  
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.ec2"
  vpc_endpoint_type = "Interface"
  security_group_ids  = ["${aws_security_group.ec2.id}"]
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true
}

resource "aws_security_group" "ec2" {
  name_prefix = "k8s-vpc-endpoint-ec2-"
  description = "EC2 VPC Endpoint Security Group"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "vpc_endpoint_ec2_https" {
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = "${aws_security_group.ec2.id}"
}


############################
# VPC Endpoint for SSM & ECR
############################

resource "aws_vpc_endpoint" "ssm" {
  
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type = "Interface"
  security_group_ids  = ["${aws_security_group.ssm_ecr.id}"]
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_api" {
  
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type = "Interface"
  security_group_ids  = ["${aws_security_group.ssm_ecr.id}"]
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  security_group_ids  = ["${aws_security_group.ssm_ecr.id}"]
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true
}

resource "aws_security_group" "ssm_ecr" {
  name_prefix = "k8s-vpc-endpoint-ssm-ecr-"
  description = "SSM and ECR VPC Endpoint Security Group"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "vpc_endpoint_ssm-ecr_https" {
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = "${aws_security_group.ssm_ecr.id}"
}
