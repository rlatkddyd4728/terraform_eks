locals {
    karpenter_node_managed_policy = [
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    ]

    helm_chart = {
        aws-load-balancer-controller = {
            repository          = "https://aws.github.io/eks-charts"
            namespace           = "kube-system"
            version             = "latest"
            set                 = {
                "clusterName"                   = "${data.terraform_remote_state.eks.outputs.cluster_name}"
                "serviceAccount.create"         = "true"
                "serviceAccount.name"           = "aws-load-balancer-controller"
                "enableServiceMutatorWebhook"   = "false"
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

        argo-cd = {
            repository          = "https://argoproj.github.io/argo-helm"
            namespace           = "argocd"
            version             = "latest"
            set                 = {
                # "server.extraArgs"      = "{--insecure}"
                "nameOverride"          = "" 
            }
            manifest            = [
                "argocd-cm.yaml", "argocd-rbac.yaml"
            ]    
        }

        karpenter = {
            repository          = "oci://public.ecr.aws/karpenter"
            namespace           = "karpenter"
            version             = "0.37.0"
            repository_username = data.aws_ecrpublic_authorization_token.token.user_name
            repository_password = data.aws_ecrpublic_authorization_token.token.password
            set                 = {
                "settings.clusterName"                                      = "${data.terraform_remote_state.eks.outputs.cluster_name}" 
                "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = "${module.karpenter.iam_role_arn}"
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