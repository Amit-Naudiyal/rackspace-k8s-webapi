#SSM Parameter read by python application

resource "aws_ssm_parameter" "interview-parameter" {
  name = local.ssm_param_key
  value = local.ssm_param_value
  type  = "String"
}