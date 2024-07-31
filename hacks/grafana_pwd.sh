name=$(kubectl get secrets -nobs | grep grafana | cut -d' ' -f1)
kubectl get secret $name -nobs -o jsonpath="{.data.admin-password}" | base64 --decode
