module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = format("%-%s",var.prefix,var.env)
  cluster_version = "1.31"

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
  iam_role_arn                              = aws_iam_role.eks_cluster.arn

  #-----------------------------------------------------
  # Node groups Attributes
  #-----------------------------------------------------

  eks_managed_node_group_defaults = {
      ami_type                                = "AL2023_x86_64_STANDARD"   // AL2_x86_64 or AL2023_x86_64_STANDARD
      ami_release_version                     = "1.31.4-20250203"
      
      # Launch Template
      update_launch_template_default_version  = true
      launch_template_use_name_prefix         = false
      use_name_prefix                         = false
      create_iam_role                         = false
      enable_monitoring                       = false
      iam_role_arn                            = aws_iam_role.eks_node.arn
      vpc_security_group_ids                  = [data.aws_security_group.common.id]
      subnet_ids                              = data.aws_subnets.pri_sub.ids
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

      metadata_options ={
          http_endpoint               = "enabled"
          http_tokens                 = "required"  # IMDSv2 사용
          http_put_response_hop_limit = 2
      }

      ## AMI TYPE : AL2 ##
      # pre_bootstrap_user_data     = file("../userdata/AL2_post_script.sh")     
      
      ## AMI TYPE : AL2023 ##
      cloudinit_pre_nodeadm = concat(
        [{
          content      = file("../userdata/AL2023_post_script.sh")
          content_type = "text/x-shellscript; charset=\"us-ascii\""
        }],
        [{
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              kubelet:
                config:
                  imageGCHighThresholdPercent: 70 
                  imageGCLowThresholdPercent: 50
          EOT
        }]
      )

      enable_bootstrap_user_data  = false

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
        aws eks update-kubeconfig --name ${module.eks.cluster_name} --alias ${module.eks.cluster_name} --region ${var.region_id}
EOT
  }
  depends_on = [module.eks]
}