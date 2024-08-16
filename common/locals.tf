locals {

    iam_roles               = ["sy_kim_ec2_role_test","aws-gamesystems-nxstage"]  ## ec2 role 및 assume role 등
    karpenter_enable        = true  ## karpenter 생성 이후, true로 변경하고 apply (기본값은 false)
    karpenter_iam_roles     = [format("%s_%s_karpenter_node",var.prefix,var.env)]  
    iam_users               = ["sy_kim"]
    iam_node_managed_policy =  {
        eks_cluster         = [
            "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
            "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
        ]
        eks_node            = [
            "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
            "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
            "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
            "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        ]
    }

    aws_auth_roles      = concat(
        [for role in local.iam_roles : 
        {
        rolearn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${role}"
        username        = "${role}"
        groups          = ["system:masters"]
        }],
        local.karpenter_enable == false ? [] : [for role in local.karpenter_iam_roles : 
        {
        rolearn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${role}"
        username        = "system:node:{{EC2PrivateDNSName}}"
        groups          = ["system:bootstrappers", "system:nodes"]
        }]
    )

    aws_auth_users      = [for user in local.iam_users : 
        {
        userarn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${user}"
        username        = "${user}"
        groups          = ["system:masters"]
        }
    ]

    node_group          = {
        common          = {
            name                  = "common"
            create                = true
            launch_template_name  = format("%s_%s_common",var.prefix,var.env)
            instance_types        = ["c5.xlarge"]
            subnets               = data.aws_subnets.pri_sub.ids
            #scaling option
            desired_size          = 2
            max_size              = 2
            min_size              = 2
            labels                = {
                role = "common"
                env  = "dev"
            }
        }
    }
}