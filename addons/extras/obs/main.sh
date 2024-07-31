helm install kube-prometheus-stack \
  --create-namespace \
  --namespace obs \
  -f $1/values.yaml \
  prometheus-community/kube-prometheus-stack
