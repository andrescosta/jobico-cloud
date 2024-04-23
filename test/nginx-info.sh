

POD_NAME=$(kubectl get pods -l app=nginx \
  -o jsonpath="{.items[0].metadata.name}")

curl --head http://127.0.0.1:8080

kubectl logs $POD_NAME

kubectl exec -ti $POD_NAME -- nginx -v

kubectl expose deployment nginx \
  --port 80 --type NodePort

