#! /bin/bash

function prometheus {
    echo "prometheus uninstall"

    ## helm uninstall
    helm uninstall prometheus -n monitoring prometheus-community/kube-prometheus-stack

    ## prometheus alertmanger rule
    kubectl delete -f prometheus-rule/karpenter-node-rule.yaml 
    kubectl delete -f prometheus-rule/pod-rule.yaml

    ## servicemonitor
    kubectl delete -f prometheus-rule/servicemonitor.yaml
}
prometheus


function need_resource {
    echo "need resoucre uninstall"

    ## 쿠버네티스 시크릿 제거
    kubectl delete secret thanos-objstore-config -n monitoring

    ## storageclass gp3 제거
    kubectl delete -f storageclass_gp3.yaml
}
need_resource