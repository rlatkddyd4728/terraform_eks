## 모니터링을 위한 prometheus stack 설치 ( prometheus, alertmanager ,operator ,grafana 등 모니터링에 필요한 여러 구성들이 함께 설치됨 )
- 기본적인 grafana 대시보드 제공 선택 (defaultDashboardsEnabled 옵션)

## namespace 생성
- kubectl create ns monitoring

## storageclass gp3 생성
- kubectl apply -f storageclass_gp3.yaml

## prometheus stack 설치
- helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
- helm repo update

## helm install
- helm install prometheus -n monitoring prometheus-community/kube-prometheus-stack -f monitoring_values.yaml -n monitoring

## servicemonitor 생성
- kubectl apply -f servicemonitor.yaml

## monitoring elb 생성
- kubectl apply -f monitoring_elb.yaml