security(){
    local registry_name="reg.$(jobico::dao::cpl::get_domain)"
    local auth_dir="$(work_dir)/auth"
    if [ ! -d $auth_dir ]; then
        mkdir $auth_dir
        docker run --rm --entrypoint htpasswd registry:2.6.2 -Bbn jobico jobico123 > $auth_dir/htpasswd
    fi
    kubectl create secret generic auth-secret --from-file=$auth_dir/htpasswd
    kubectl create secret docker-registry reg-cred-secret --docker-server=$registry_name --docker-username=jobico --docker-password=jobico123
}

manifests(){
    local domain=$(jobico::dao::cpl::get_domain)
    local docker=$(prepare_file "$1/docker-registry-pod.yaml.tmpl" "registry" "{DOMAIN}=$domain")
    kubectl apply -f $1/registry-volume.yaml
    kubectl apply -f $docker
}

deploy(){
    local registry_name="reg.$(jobico::dao::cpl::get_domain)"
    local domain=$(jobico::dao::cpl::get_domain)
    while read IP FQDN HOST SUBNET TYPE SCH; do
        SSH -n root@${IP} mkdir -p /etc/containerd/certs.d/$registry_name 
        SCP $(work_dir)/$domain.crt root@${IP}:/etc/containerd/certs.d/$registry_name/ca.crt 
        SSH root@${IP} \
<<EOF
echo  '
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.configs]
    [plugins."io.containerd.grpc.v1.cri".registry.configs."$registry_name"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs."$registry_name".tls]
        ca_file = "/etc/containerd/certs.d/$registry_name/ca.crt"
'>> /etc/containerd/config.toml
sudo systemctl restart containerd
EOF
    done < <(jobico::dao::cluster::members)
}

deploy_docker(){
    local registry_name="reg.$(jobico::dao::cpl::get_domain)"
    local domain=$(jobico::dao::cpl::get_domain)
    sudo mkdir -p /etc/docker/certs.d/$registry_name/
    sudo cp $(work_dir)/$domain.crt /etc/docker/certs.d/$registry_name/ca.crt
    sudo systemctl restart docker
}
