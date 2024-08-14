resource "kubectl_manifest" "argocd" {
  for_each            = toset(local.helm_chart.argo-cd.manifest)
  yaml_body           = file("${path.module}/argocd_manifest/${each.value}")
  override_namespace  = "argocd"

  depends_on = [helm_release.helm]
}

resource "kubectl_manifest" "argocd_service" {
  override_namespace  = "argocd"
  yaml_body           = <<YAML
apiVersion: v1
kind: Service
metadata:
  name: ${var.prefix}-${var.env}-argocd
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external             
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip       
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-name: ${var.prefix}-${var.env}-argocd       
    service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: preserve_client_ip.enabled=true               
    service.beta.kubernetes.io/aws-load-balancer-subnets: ${data.aws_subnets.pub_sub.ids[0]},${data.aws_subnets.pub_sub.ids[1]} 
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argo-cd-server
    app.kubernetes.io/part-of: argocd
  name: argocd-server
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 8080
  - name: https
    port: 443
    protocol: TCP
    targetPort: 8080
  type: LoadBalancer
  loadBalancerSourceRanges:       ## 인바운드 룰 설정
  - "119.206.206.251/32"        
  - "${data.aws_instance.mgmt.public_ip}/32"          
  selector:
    app.kubernetes.io/name: argo-cd-server
YAML

  depends_on = [helm_release.helm]
}

# resource "kubectl_manifest" "argocd_ingress" {
#   override_namespace = "argocd"
#   yaml_body = <<YAML
# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: ${var.prefix}-${var.env}-argocd
#   annotations:
#     kubernetes.io/ingress.class: alb
#     alb.ingress.kubernetes.io/target-type: ip
#     alb.ingress.kubernetes.io/load-balancer-name: ${var.prefix}-${var.env}-argocd
#     alb.ingress.kubernetes.io/scheme: internet-facing
#     alb.ingress.kubernetes.io/load-balancer-attributes: deletion_protection.enabled=false
#     alb.ingress.kubernetes.io/healthcheck-protocol: HTTPS
#     alb.ingress.kubernetes.io/subnets: ${data.aws_subnets.pub_sub.ids[0]},${data.aws_subnets.pub_sub.ids[1]}
#     alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
#     alb.ingress.kubernetes.io/inbound-cidrs: '119.206.206.251/32, ${data.aws_instance.mgmt.public_ip}/32'
# spec:
#   rules:
#   - http:
#       paths:
#       - path: /*
#         pathType: ImplementationSpecific
#         backend:
#             service:
#                 name: argo-cd-server
#                 port:
#                   number: 80
#       paths:
#       - path: /*
#         pathType: ImplementationSpecific
#         backend:
#             service:
#                 name: argo-cd-server
#                 port:
#                   number: 443
# YAML

#   depends_on = [helm_release.helm]
# }

resource "null_resource" "argocd_password" {
  provisioner "local-exec" {
    working_dir = "./argocd_manifest"
    command     = <<EOT
      kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath={.data.password} | base64 -d > argocd-login.txt
EOT
  }
  depends_on = [helm_release.helm]
}