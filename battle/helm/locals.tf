locals {
    
    enable = {
        ## node scaling 을 위한 것으로 2개 중에 하나만 선택 그리고 선택하지 않은 것은 아래 helm_chart 에서 주석 처리
        karpenter               = true    ## true or false
        cluster_autoscaler      = false    ## true or false
    }

    karpenter = {
        version = "0.37.0"
        karpenter_node_managed_policy = [
            "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
            "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
            "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
            "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
            "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        ]
    }

    helm_chart = {
        aws-load-balancer-controller = {
            repository          = "https://aws.github.io/eks-charts"
            namespace           = "kube-system"
            version             = "latest"
            set                 = {
                "clusterName"                                                       = "${data.terraform_remote_state.eks.outputs.cluster_name}"
                "serviceAccount.create"                                             = "true"
                "serviceAccount.name"                                               = "aws-load-balancer-controller"
                "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"         = "${module.aws_load_balancer_controller.iam_role_arn}"
                "enableServiceMutatorWebhook"                                       = "false"
            }
        }

        metrics-server = {
            repository          = "https://kubernetes-sigs.github.io/metrics-server/"
            namespace           = "kube-system"
            version             = "latest"
            set                 = {
                "replicas"             = "1"
            }
        }

        # cluster-autoscaler = {
        #     repository          = "https://kubernetes.github.io/autoscaler"
        #     namespace           = "kube-system"
        #     version             = "latest"
        #     set                 = {
        #         "autoDiscovery.clusterName"                                         = "${data.terraform_remote_state.eks.outputs.cluster_name}"
        #         "autoDiscovery.enabled"                                             = "true"
        #         "extraArgs.skip-nodes-with-system-pods"                             = "false"
        #         "rbac.create"                                                       = "true"
        #         "rbac.serviceAccount.create"                                        = "true"
        #         "rbac.serviceAccount.name"                                          = "cluster-autoscaler"
        #         "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"    = "${module.cluster_autoscaler[0].iam_role_arn}"
        #     }
        # }

        karpenter-crd = {
            repository          = "oci://public.ecr.aws/karpenter"
            namespace           = "karpenter"
            version             = local.karpenter.version
            repository_username = data.aws_ecrpublic_authorization_token.token.user_name
            repository_password = data.aws_ecrpublic_authorization_token.token.password
        }

        karpenter = {
            repository          = "oci://public.ecr.aws/karpenter"
            namespace           = "karpenter"
            version             = local.karpenter.version
            repository_username = data.aws_ecrpublic_authorization_token.token.user_name
            repository_password = data.aws_ecrpublic_authorization_token.token.password
            skip_crds           = true          ## crd 설치 X
            set                 = {
                "settings.clusterName"                                      = "${data.terraform_remote_state.eks.outputs.cluster_name}" 
                "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = "${module.karpenter[0].iam_role_arn}"
                "controller.resources.requests.cpu"                         = "1"
                "controller.resources.requests.memory"                      = "1Gi"
                "controller.resources.limits.cpu"                           = "1"
                "controller.resources.limits.memory"                        = "1Gi"
            }
        }

    }
}


# helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version "0.37.0" --namespace "karpenter" \
#   --set "settings.clusterName=ksy_dev" \
#   --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=arn:aws:iam::827398730268:role/ksy_dev_karpenter_controller" \
#   --set controller.resources.requests.cpu=1 \
#   --set controller.resources.requests.memory=1Gi \
#   --set controller.resources.limits.cpu=1 \
#   --set controller.resources.limits.memory=1Gi