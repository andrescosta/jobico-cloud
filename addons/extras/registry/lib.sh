REGISTRY_NAME="reg.jobico.org"

security(){
    if [ ! -d $1/certs ]; then
        mkdir $1/certs
        openssl req -x509 -newkey rsa:4096 -days 365 -nodes -sha256 -keyout $1/certs/tls.key -out $1/certs/tls.crt -subj "/CN=docker-registry,/CN=reg.jobico.org" -addext "subjectAltName = DNS:docker-registry,DNS:reg.jobico.org"
    fi
    if [ ! -d $1/auth ]; then
        mkdir $1/auth
        docker run --rm --entrypoint htpasswd registry:2.6.2 -Bbn jobico jobico123 > $1/auth/htpasswd
    fi
    kubectl create secret tls certs-secret --cert=$1/certs/tls.crt --key=$1/certs/tls.key
    kubectl create secret generic auth-secret --from-file=$1/auth/htpasswd
    kubectl create secret docker-registry reg-cred-secret --docker-server=$REGISTRY_NAME --docker-username=jobico --docker-password=jobico123
}

manifests(){
    kubectl apply -f $1/registry-volume.yaml
    kubectl apply -f $1/docker-registry-pod.yaml
}

deploy(){
    while read IP FQDN HOST SUBNET TYPE SCH; do
        SSH -n root@${IP} mkdir -p /etc/containerd/certs.d/$REGISTRY_NAME 
        SCP $1/certs/tls.crt root@${IP}:/etc/containerd/certs.d/$REGISTRY_NAME/ca.crt 
        SSH root@${IP} \
<< 'EOF'
echo  '
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.configs]
    [plugins."io.containerd.grpc.v1.cri".registry.configs."reg.jobico.org"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs."reg.jobico.org".tls]
        ca_file = "/etc/containerd/certs.d/reg.jobico.org/ca.crt"
'>> /etc/containerd/config.toml
sudo systemctl restart containerd
EOF
    done < <(jobico::dao::cluster::members)
}

