data "aws_vpc" "vpc_id" {
  filter {
    name    = "tag:Name"
    values  = ["sy_kim_VPC"]
  }
}

data "aws_subnets" "pri_sub" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_id.id]
  }

  filter {
    name = "tag:Name"
    values = ["sy_kim_pri_*"]
  }
}

data "aws_security_group" "common" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_id.id]
  }

  filter {
    name = "tag:Name"
    values = ["sy_kim_common_sg"]
  }
}

data "aws_caller_identity" "current" {}