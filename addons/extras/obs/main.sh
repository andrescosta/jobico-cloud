helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install --create-namespace \
  --values $1/values-loki.yaml \
  loki \
  --namespace=obs \
  grafana/loki

helm install tempo grafana/tempo --namespace=obs

helm install pyroscope grafana/pyroscope --namespace=obs

helm install kube-prometheus-stack \
  --create-namespace \
  --namespace obs \
  -f $1/values.yaml \
  prometheus-community/kube-prometheus-stack


helm install prometheus-postgres-exporter \
 prometheus-community/prometheus-postgres-exporter -nobs -f $1/values-pg.yaml

kubectl apply -nobs -f $1/dashboards-jvm-micrometer.yaml
kubectl apply -nobs -f $1/dashboards-trace.yaml
kubectl apply -nobs -f $1/dashboards-pg.yaml
kubectl apply -nobs -f $1/monitor.yaml
