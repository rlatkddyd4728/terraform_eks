module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  # version = "~> 20.0"
  version = "20.8.5"

  cluster_name    = format("%s_%s",var.prefix,var.env)
  cluster_version = "1.30"

  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                                    = data.aws_vpc.vpc_id.id
  cluster_additional_security_group_ids     = [data.aws_security_group.common.id]
  subnet_ids                                = data.aws_subnets.pri_sub.ids   ## pri subnet
  control_plane_subnet_ids                  = data.aws_subnets.pri_sub.ids   ## pri subnet

  create_cloudwatch_log_group               = true
  cloudwatch_log_group_retention_in_days    = 1
  create_cluster_security_group             = false
  create_iam_role                           = false
  create_node_security_group                = false
  enable_cluster_creator_admin_permissions  = true
  iam_role_arn                              = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/sy_kim_eks_role"

  #-----------------------------------------------------
  # Node groups Attributes
  #-----------------------------------------------------

  eks_managed_node_group_defaults = {
      ami_type                                = "AL2023_x86_64_STANDARD"
      ami_release_version                     = "1.30.0-20240625"
      
      # Launch Template
      update_launch_template_default_version  = true
      launch_template_use_name_prefix         = false
      use_name_prefix                         = false
      create_iam_role                         = false
      enable_monitoring                       = false
      iam_role_arn                            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/sy_kim_eks_node_role"
      vpc_security_group_ids                  = [data.aws_security_group.common.id]
      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs         = {
            volume_size           = 50
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            delete_on_termination = true
          }    
        }  
      }    
      capacity_type               = "ON_DEMAND"
      key_name                    = "sy_kim_keypair"
      pre_bootstrap_user_data     = file("./userdata/post_script.sh")
      enable_bootstrap_user_data  = true

  }

  eks_managed_node_groups = local.node_group
}

module "eks-aws-auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "~> 20.0"

  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_roles = local.aws_auth_roles

  aws_auth_users = local.aws_auth_users

  depends_on = [module.eks]
}

#-----------------------------------------------------
# EKS Cluster Kube Config Update
#-----------------------------------------------------
resource "null_resource" "eks_kubeconfig" {
  provisioner "local-exec" {
    command     = <<EOT
        aws eks update-kubeconfig --name ${module.eks.cluster_name}
EOT
  }
  depends_on = [module.eks]
}