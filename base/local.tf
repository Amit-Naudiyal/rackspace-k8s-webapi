locals {
  cluster_name = "interview-test-cluster"
  cluster_version = "1.21"
  cluster_endpoint_access_ips = [ "159.196.168.153/32" ]
  
  key_name = "microservice-key"

  tags = {
    cluster    = local.cluster_name
    reference = "terraform-aws-eks"
  }

  ecr_repo_name  = "testapp"
  ssm_param_key = "interview-parameter"
  ssm_param_value = "Interview Param Value"

  app_namespace = "interview-namespace"
  eks_pod_role_name = "eks_pod_iam_role"

}