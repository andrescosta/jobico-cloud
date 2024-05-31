docker pull nginx
docker tag nginx:latest reg.jobico.org/mynginx:v1
if [i ! -f /etc/docker/certs.d/reg.jobico.org/ca.crt ]; then
    sudo cp addons/extras/registry/certs/tls.crt /etc/docker/certs.d/reg.jobico.org/ca.crt
fi
docker login reg.jobico.org -u myuser -p mypasswd
docker push reg.jobico.org/mynginx:v1
kubectl run nginx-pod --image=reg.jobico.org/mynginx:v1 --overrides='{ "apiVersion": "v1", "spec": { "imagePullSecrets": [{"name": "reg-cred-secret"}] } }'
