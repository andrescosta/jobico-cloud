docker login docker-registry:5000 -u jobico -p jobico123
#docker pull nginx
#docker tag nginx:latest docker-registry:5000/mynginx:v1
#docker push docker-registry:5000/mynginx:v1

#kubectl exec docker-registry-pod -it -- sh
/ # ls /var/lib/registry/docker/registry/v2/repositories/
#kubectl run nginx-pod --image=docker-registry:5000/mynginx:v1 --overrides='{ "apiVersion": "v1", "spec": { "imagePullSecrets": [{"name": "reg-cred-secret"}] } }'