#! /bin/bash

function need_resource {
    echo "need resoucre install"

    ## namespace 생성
    kubectl create ns monitoring

    ## storageclass gp3 생성
    kubectl apply -f storageclass_gp3.yaml

    ## 쿠버네티스 시크릿 생성
    kubectl create secret generic thanos-objstore-config -n monitoring --from-file=objstore.yaml
}
need_resource

function prometheus {
    echo "prometheus install"

    ## prometheus stack 설치
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    ## helm install
    helm install prometheus -n monitoring prometheus-community/kube-prometheus-stack -f prometheus-stack/values.yaml

    ## prometheus alertmanger rule
    kubectl apply -f prometheus-rule/karpenter-node-rule.yaml 
    kubectl apply -f prometheus-rule/pod-rule.yaml

    ## servicemonitor
    kubectl apply -f prometheus-rule/servicemonitor.yaml 
}
prometheus
