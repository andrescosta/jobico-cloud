helm install kube-prometheus-stack \
  --create-namespace \
  --namespace obs \
  -f $1/values.yaml \
  prometheus-community/kube-prometheus-stack


helm install prometheus-postgres-exporter \
 prometheus-community/prometheus-postgres-exporter -nobs -f $1/values-pg.yaml

kubectl apply -f $1/monitor.yaml
