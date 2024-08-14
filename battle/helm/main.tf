module "cluster_autoscaler" {
    count     = local.enable.cluster_autoscaler ? 1 : 0
    source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    role_name = format("%s_%s_%s_cluster_autoscaler",var.prefix,var.env,var.role)

    attach_cluster_autoscaler_policy      = true
    cluster_autoscaler_cluster_names      = [data.terraform_remote_state.eks.outputs.cluster_name]

    oidc_providers = {
        main = {
            provider_arn               = data.terraform_remote_state.eks.outputs.oidc_provider_arn
            namespace_service_accounts = ["kube-system:cluster-autoscaler"]
        }

    }
}


module "karpenter" {
    count     = local.enable.karpenter ? 1 : 0
    source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    role_name = format("%s_%s_%s_karpenter_controller",var.prefix,var.env,var.role)

    attach_karpenter_controller_policy      = false

    role_policy_arns = {
        policy = aws_iam_policy.karpenter[0].arn
    }

    oidc_providers = {
        main = {
            provider_arn               = data.terraform_remote_state.eks.outputs.oidc_provider_arn
            namespace_service_accounts = ["karpenter:karpenter"]
        }

    }

    depends_on = [aws_iam_policy.karpenter]
}

module "aws_load_balancer_controller" {
    source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    role_name = format("%s_%s_%s_aws_load_balancer_controller",var.prefix,var.env,var.role)

    attach_load_balancer_controller_policy  = true

    oidc_providers = {
        main = {
            provider_arn               = data.terraform_remote_state.eks.outputs.oidc_provider_arn
            namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
        }

    }
}

resource "helm_release" "helm" {
    for_each            = local.helm_chart
    name                = each.key
    repository          = each.value.repository
    chart               = each.key
    namespace           = each.value.namespace
    version             = each.value.version == "latest" ? null : each.value.version
    repository_username = lookup(each.value, "repository_username", null)
    repository_password = lookup(each.value, "repository_password", null)
    skip_crds           = lookup(each.value, "skip_crds", false)
    timeout             = 300
    create_namespace    = true

    dynamic "set" {
        for_each    = lookup(each.value, "set", null) == null ? {} : {for k, v in each.value.set: k => v}
        content {
            name    = set.key
            value   = set.value
        }
    }
    depends_on = [
        module.cluster_autoscaler,
        module.karpenter,
        module.aws_load_balancer_controller
    ]

    lifecycle {
        ignore_changes = [repository_password]
    }

}

## https://karpenter.sh/v0.37/troubleshooting/#helm-error-when-installing-the-karpenter-crd-chart
resource "null_resource" "karpenter-crd" {
  count         = local.enable.karpenter ? 1 : 0 
  provisioner "local-exec" {
    command     = <<EOT
        kubectl label crd ec2nodeclasses.karpenter.k8s.aws nodepools.karpenter.sh nodeclaims.karpenter.sh app.kubernetes.io/managed-by=Helm --overwrite
        kubectl annotate crd ec2nodeclasses.karpenter.k8s.aws nodepools.karpenter.sh nodeclaims.karpenter.sh meta.helm.sh/release-name=karpenter-crd --overwrite
        kubectl annotate crd ec2nodeclasses.karpenter.k8s.aws nodepools.karpenter.sh nodeclaims.karpenter.sh meta.helm.sh/release-namespace=karpenter --overwrite
EOT
  }
  depends_on    = [helm_release.helm]
}

## terraform destroy를 하면 argocd crd는 제거되지 않음
# resource "null_resource" "argocd" {
#   provisioner "local-exec" {
#     when        = destroy
#     command     = <<EOT
#         kubectl delete crds applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io
# EOT
#   }
#   depends_on = [helm_release.helm]
# }