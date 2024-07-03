locals {
  tfstate   = {
    eks     = "terraform/test/eks.tfstate"
  }
}

data "terraform_remote_state" "eks" {
  backend   = "s3"

  config    = {
    bucket  = "s3-sykim-ops"
    key     = local.tfstate.eks
    region  = var.region_id
  }
}

data "aws_vpc" "vpc_id" {
  filter {
    name    = "tag:Name"
    values  = ["sy_kim_VPC"]
  }
}

data "aws_subnets" "pub_sub" {
  filter {
    name    = "vpc-id"
    values  = [data.aws_vpc.vpc_id.id]
  }

  filter {
    name    = "tag:Name"
    values  = ["sy_kim_pub_*"]
  }
}

data "aws_instance" "mgmt" {
  filter {
    name    = "tag:Name"
    values  = ["sy_kim_eks"]
  }
}

data "aws_ecrpublic_authorization_token" "token" {
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecrpublic_authorization_token
    provider = aws.virginia
}