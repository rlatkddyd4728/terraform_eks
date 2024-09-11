terraform {
  required_version = ">= 1.3.2"             ## 테라폼 버전
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.61.0"                 ## 프로바이더 aws 버전
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
  backend "s3" {
    bucket = "s3-sykim-ops"                       ## s3가 미리 생성되어 있어야 함
    region = "ap-southeast-3"                     ## s3 버킷이 있는 리전
    key    = "terraform/test/helm.tfstate"         ## terraform apply하고 나서 저장되는 s3 경로
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
    }
  }
}

provider "aws" {
  region  = var.region_id
}

provider "aws" {
  region  = "us-east-1"
  alias   = "virginia"
}
