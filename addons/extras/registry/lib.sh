REGISTRY_NAME="reg.jobico.org"

security(){
    if [ ! -d $1/auth ]; then
        mkdir $1/auth
        docker run --rm --entrypoint htpasswd registry:2.6.2 -Bbn jobico jobico123 > $1/auth/htpasswd
    fi
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
        SCP $WORK_DIR/jobico.org.crt root@${IP}:/etc/containerd/certs.d/$REGISTRY_NAME/ca.crt 
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

deploy_docker(){
    sudo mkdir -p /etc/docker/certs.d/reg.jobico.org/
    sudo cp $WORK_DIR/jobico.org.crt /etc/docker/certs.d/reg.jobico.org/ca.crt
    sudo systemctl restart docker
}
