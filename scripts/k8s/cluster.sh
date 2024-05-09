
kube::cluster::deploy_to_server(){
    local servers=($(kube::dao::cluster::get server 1))
    for host in ${servers[@]}; do
        scp ${DOWNLOADS_DIR}/kube-apiserver \
        ${DOWNLOADS_DIR}/kube-controller-manager \
        ${DOWNLOADS_DIR}/kube-scheduler \
        ${DOWNLOADS_DIR}/kubectl \
        ${WORK_DIR}/kube-apiserver.service \
        ${EXTRAS_DIR}/units/kube-controller-manager.service \
        ${EXTRAS_DIR}/units/kube-scheduler.service \
        ${EXTRAS_DIR}/configs/kube-scheduler.yaml \
        ${EXTRAS_DIR}/configs/kube-apiserver-to-kubelet.yaml root@$host:~/
    
        ssh root@$host \
<< 'EOF'
  mkdir -p /etc/kubernetes/config
  chmod +x kube-apiserver \
    kube-controller-manager \
    kube-scheduler kubectl

  mv kube-apiserver \
    kube-controller-manager \
    kube-scheduler kubectl \
    /usr/local/bin

  mkdir -p /var/lib/kubernetes

  mv ca.crt ca.key \
    kube-api-server.key kube-api-server.crt \
    service-accounts.key service-accounts.crt \
    encryption-config.yaml \
    /var/lib/kubernetes

  mv kube-apiserver.service \
    /etc/systemd/system/kube-apiserver.service

  mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
  mv kube-controller-manager.service /etc/systemd/system/
  mv kube-scheduler.kubeconfig /var/lib/kubernetes/
  mv kube-scheduler.yaml /etc/kubernetes/config/
  mv kube-scheduler.service /etc/systemd/system/

  systemctl daemon-reload
  systemctl enable kube-apiserver \
    kube-controller-manager kube-scheduler

  systemctl start kube-apiserver \
    kube-controller-manager kube-scheduler

  sleep 10

  kubectl cluster-info \
    --kubeconfig admin.kubeconfig

  kubectl apply -f kube-apiserver-to-kubelet.yaml \
    --kubeconfig admin.kubeconfig

EOF
    done
}

## Nodes deployment

kube::cluster::deploy_to_nodes(){
    local workers=($(kube::dao::cpl::get worker))
    for host in ${workers[@]}; do
        subnets=$(grep $host $MACHINES_DB | cut -d " " -f 4)
        sed "s|SUBNET|${subnets}|g" \
        ${EXTRAS_DIR}/configs/10-bridge.conf > ${WORK_DIR}/10-bridge.conf
        
        sed "s|SUBNET|${subnets}|g" \
        ${EXTRAS_DIR}/configs/kubelet-config.yaml > ${WORK_DIR}/kubelet-config.yaml
        
        scp ${WORK_DIR}/10-bridge.conf \
        ${WORK_DIR}/kubelet-config.yaml \
        root@$host:~/
    done
    
    for host in ${workers[@]}; do
        scp ${DOWNLOADS_DIR}/runc.amd64 \
        ${DOWNLOADS_DIR}/crictl-v1.28.0-linux-amd64.tar.gz \
        ${DOWNLOADS_DIR}/cni-plugins-linux-amd64-v1.3.0.tgz \
        ${DOWNLOADS_DIR}/containerd-1.7.8-linux-amd64.tar.gz \
        ${DOWNLOADS_DIR}/kubectl \
        ${DOWNLOADS_DIR}/kubelet \
        ${DOWNLOADS_DIR}/kube-proxy \
        ${EXTRAS_DIR}/configs/99-loopback.conf \
        ${EXTRAS_DIR}/configs/containerd-config.toml \
        ${EXTRAS_DIR}/configs/kube-proxy-config.yaml \
        ${EXTRAS_DIR}/units/containerd.service \
        ${EXTRAS_DIR}/units/kubelet.service \
        ${EXTRAS_DIR}/units/kube-proxy.service root@$host:~/
    done
    
    for host in ${workers[@]}; do
        ssh root@$host \
<< 'EOF'

  swapoff -a

  mkdir -p \
    /etc/cni/net.d \
    /opt/cni/bin \
    /var/lib/kubelet \
    /var/lib/kube-proxy \
    /var/lib/kubernetes \
    /var/run/kubernetes

  mkdir -p containerd
  tar -xvf crictl-v1.28.0-linux-amd64.tar.gz
  tar -xvf containerd-1.7.8-linux-amd64.tar.gz -C containerd
  tar -xvf cni-plugins-linux-amd64-v1.3.0.tgz -C /opt/cni/bin/
  mv runc.amd64 runc
  chmod +x crictl kubectl kube-proxy kubelet runc
  mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
  mv containerd/bin/* /bin/

  mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/
  mkdir -p /etc/containerd/
  mv containerd-config.toml /etc/containerd/config.toml
  mv containerd.service /etc/systemd/system/
  mv kubelet-config.yaml /var/lib/kubelet/
  mv kubelet.service /etc/systemd/system/
  mv kube-proxy-config.yaml /var/lib/kube-proxy/
  mv kube-proxy.service /etc/systemd/system/

  systemctl daemon-reload
  systemctl enable containerd kubelet kube-proxy
  systemctl start containerd kubelet kube-proxy

EOF
        
    done
}

kube::cluster::add_routes(){
    local servers=($(kube::dao::cpl::control_plane))
    for server in "${servers[@]}"; do
        kube::dao::cluster::nodes | while read IP FQDN HOST SUBNET TYPE; do
            ssh root@${server} \
<<EOF 
    sed -i "/set-name: enp1s0/a\            routes:\n              - to: ${SUBNET}\n                via: ${IP}" /etc/netplan/50-cloud-init.yaml 
    netplan apply
EOF
        done
    done
    kube::dao::cluster::all_nodes | while read IP1 FQDN1 HOST1 SUBNET1 TYPE1; do
        kube::dao::cluster::nodes | while read IP2 FQDN2 HOST2 SUBNET2 TYPE2; do
            if [ "${IP1}" != "${IP2}" ]; then
                ssh root@${IP1} \
<<EOF 
    sed -i "/set-name: enp1s0/a\            routes:\n              - to: ${SUBNET2}\n                via: ${IP2}" /etc/netplan/50-cloud-init.yaml 
    netplan apply
EOF
            fi
        done
    done
}

kube::cluster::add_routes_to_added_node(){
    kube::dao::cluster::nodes | while read IP1 FQDN1 HOST1 SUBNET1 TYPE1; do
        kube::dao::cluster::curr_nodes | while read IP2 FQDN2 HOST2 SUBNET2 TYPE2; do
            ssh root@${IP1} \
<<EOF 
    sed -i "/set-name: enp1s0/a\            routes:\n              - to: ${SUBNET2}\n                via: ${IP2}" /etc/netplan/50-cloud-init.yaml 
    netplan apply
EOF
        done
    done
}
