#mkdir certs
#mkdir auth
#openssl req -x509 -newkey rsa:4096 -days 365 -nodes -sha256 -keyout $1/certs/tls.key -out $1/certs/tls.crt -subj "/CN=docker-registry,/CN=reg.jobico.org" -addext "subjectAltName = DNS:docker-registry,DNS:reg.jobico.org"
#docker run --rm --entrypoint htpasswd registry:2.6.2 -Bbn myuser mypasswd > auth/htpasswd
kubectl create secret tls certs-secret --cert=$1/certs/tls.crt --key=$1/certs/tls.key
kubectl create secret generic auth-secret --from-file=$1/auth/htpasswd
kubectl apply -f $1/registry-volume.yaml
kubectl apply -f $1/docker-registry-pod.yaml
REGISTRY_NAME="reg.jobico.org"
#export REGISTRY_IP="10.32.0.200"
#for x in $(kubectl get nodes -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }'); do ssh root@$x "echo '$REGISTRY_IP $REGISTRY_NAME' >> /etc/hosts"; done
#for x in $(kubectl get nodes -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }'); do ssh root@$x "rm -rf /etc/docker/certs.d/$REGISTRY_NAME:5000;mkdir -p /etc/docker/certs.d/$REGISTRY_NAME:5000"; done
#for x in $(kubectl get nodes -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }'); do scp $1/certs/tls.crt root@$x:/etc/docker/certs.d/$REGISTRY_NAME:5000/ca.crt; done
for x in $(kubectl get nodes -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }'); do ssh root@$x "rm -rf /etc/containerd/certs.d/$REGISTRY_NAME;mkdir -p /etc/containerd/certs.d/$REGISTRY_NAME"; done
for x in $(kubectl get nodes -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }'); do scp $1/certs/tls.crt root@$x:/etc/containerd/certs.d/$REGISTRY_NAME/ca.crt; done
for x in $(kubectl get nodes -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }'); do 
    ssh root@$x \
<< 'EOF'
echo -e '
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.configs]
    [plugins."io.containerd.grpc.v1.cri".registry.configs."reg.jobico.org"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs."reg.jobico.org".tls]
        ca_file = "/etc/containerd/certs.d/reg.jobico.org/ca.crt"
'>> /etc/containerd/config.toml
sudo systemctl restart containerd
EOF

done



kubectl create secret docker-registry reg-cred-secret --docker-server=$REGISTRY_NAME --docker-username=myuser --docker-password=mypasswd
