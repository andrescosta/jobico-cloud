helm install v1obs prometheus-community/kube-prometheus-stack -f $1/values.yaml -nobs --create-namespace
