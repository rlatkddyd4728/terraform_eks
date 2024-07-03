output "cluster_name" {
    value       = module.eks.cluster_name
}

output "cluster_arn" {
    value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
    value       = module.eks.cluster_certificate_authority_data
}

output "cluster_endpoint" {
    value       = module.eks.cluster_endpoint
}

# output "nodegroup_iam_role_arn" {
#     value       = values(module.eks.eks_managed_node_groups)[0].iam_role_arn
# }

output "oidc_provider_arn" {
    value       = module.eks.oidc_provider_arn   
}

